import Foundation
import Flutter
import UIKit

@MainActor final class NativeRuntime: RuntimeHost {
    let store: NativeStore, api: SessionTransport, uploads: UploadQueue
    let phone: PhoneRecorder, recorder: JwdRecorder, media: NativeMedia
    lazy var personal = NativePersonal(self)
    private let events: RuntimeEvents
    private var ticker: Task<Void,Never>?
    private var sequence: Int64 = 0
    private var source = "phone", switching = false
    init(messenger: FlutterBinaryMessenger,presenter: UIViewController) throws {
        store = try NativeStore(); api = SessionTransport(store)
        uploads = UploadQueue(store:store,api:api)
        let queue = uploads
        phone = PhoneRecorder(store:store,api:api,saved:{ queue.saved($0) })
        recorder = JwdRecorder(store:store,api:api,saved:{ queue.saved($0) })
        media = NativeMedia(store:store,api:api,saved:{ queue.saved($0) }); media.presenter = presenter
        events = RuntimeEvents(binaryMessenger:messenger)
        RuntimeHostSetup.setUp(binaryMessenger:messenger,api:NativeBridge(self))
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                if let self, UIApplication.shared.applicationState == .active {
                    try? await self.events.changed(state:self.state())
                    await self.uploads.pollProcessing()
                }
                try? await Task.sleep(nanoseconds:500_000_000)
            }
        }
    }
    private func signedIn() throws {
        guard store.state().signedIn,!switching else { throw RuntimeFailure("SIGN_IN","Sign in to continue.") }
    }
    private func accountIdle() throws {
        guard !phone.active,!recorder.active,!recorder.receiving,!switching else {
            throw RuntimeFailure("CAPTURE_ACTIVE","Finish the recording or reconnect your recorder before changing accounts.")
        }
    }
    private func state() -> RuntimeState {
        sequence += 1
        let useDevice = recorder.active || source == "device" && !phone.active
        let candidate = useDevice ? recorder.localId : phone.id
        let id = candidate.hasPrefix("jwd:") || (try? store.draft(candidate)) != nil ? candidate : ""
        let preview = useDevice ? recorder.preview : phone.preview
        var notes = ""
        if id.hasPrefix("jwd:") { notes = store.notes(id) }
        else if !id.isEmpty { notes = string((try? store.draft(id))?["notes"]) }
        let capture = CaptureState(source:useDevice ? "device" : "phone",phase:useDevice ? recorder.phase : phone.phase,
            elapsedMs:useDevice ? recorder.elapsed : phone.elapsed,localId:id,status:useDevice ? recorder.status : phone.status,
            partial:preview?.partial ?? "",segmentsJson:jsonString(preview?.segments ?? []),notes:notes,previewStatus:useDevice && recorder.active && preview == nil ? "Waiting for recorder audio" : preview?.status ?? "")
        let drafts = store.drafts().map { value -> JSONObject in var item = value; item.removeValue(forKey:"path"); return item }
        return RuntimeState(sequence:sequence,session:store.state(),capture:capture,device:recorder.state(),playback:media.state(),
            draftsJson:jsonString(drafts),uploadStatus:uploads.status,openRoute:"")
    }
    func snapshot() async throws -> RuntimeState { state() }
    func login(server: String,username: String,password: String) async throws -> SessionState {
        try accountIdle()
        guard !store.state().signedIn else { throw RuntimeFailure("ACCOUNT","Sign out before changing accounts.") }
        switching = true; defer { switching = false }
        try await api.login(server:server,username:username,password:password)
        phone.recover(); uploads.resumeAccount(); return store.state()
    }
    func logout() async throws {
        try accountIdle(); switching = true; defer { switching = false }
        await uploads.pauseAccount()
        _ = try? await api.json("POST","/api/v1/auth/logout",body:[:])
        personal.cancelAccountUI()
        media.stop(); phone.preview?.close(); phone.preview=nil; recorder.preview?.close(); recorder.preview=nil
        try store.logout()
    }
    func request(method: String,path: String,jsonBody: String?) async throws -> String {
        try signedIn()
        guard ["GET","POST","PATCH","DELETE"].contains(method) else { throw RuntimeFailure("API_METHOD","Unsupported request method.") }
        let body = try jsonBody.map { try jsonObject(Data($0.utf8)) }
        let bytes = try await api.data(method,path,body:body)
        if method == "POST", path.hasSuffix("/retry"), let result = try? jsonObject(bytes) { uploads.processingRetry(path, result:result) }
        return bytes.isEmpty ? "{}" : String(data:bytes,encoding:.utf8) ?? "{}"
    }
    func configure(cloudUpload: Bool,wifiOnly: Bool,livePreview: Bool) async throws {
        try signedIn(); store.configure(cloud:cloudUpload,wifi:wifiOnly,live:livePreview); uploads.resume()
    }
    func startPhone(title: String) async throws -> String {
        try signedIn()
        guard !recorder.active else { throw RuntimeFailure("DEVICE_RECORDING","Finish the recorder session first.") }
        media.stop(); source = "phone"; return try await phone.start(title)
    }
    func controlPhone(action: PhoneAction) async throws {
        switch action {
        case .pause: phone.pause()
        case .resume: try phone.resume()
        case .stop: try phone.stop()
        case .retryPreview: phone.preview?.retry()
        }
    }
    func controlDevice(action: DeviceAction,identifier: String,name: String) async throws {
        if action == .start {
            try signedIn()
            guard !phone.active else { throw RuntimeFailure("PHONE_RECORDING","Finish the phone recording first.") }
            media.stop(); source = "device"
        }
        if action == .sync { try signedIn(); source = "device" }
        try await recorder.command(action,id:identifier,name:name)
    }
    func bindDevice(identifier: String,name: String,key: String,createNew: Bool) async throws {
        try await recorder.bind(id:identifier,name:name,key:key,createNew:createNew)
    }
    func showDeviceKey() async throws { try await media.showDeviceKey(recorder.identifier) }
    func saveNotes(localId: String,notes: String) async throws {
        try signedIn()
        guard notes.utf8.count <= 180000 else { throw RuntimeFailure("NOTES_LIMIT","Recording notes are too long.") }
        if localId.hasPrefix("jwd:") { store.saveNotes(localId,notes) }
        else { var draft = try store.draft(localId); draft["notes"] = notes; try store.save(draft) }
    }
    func retryUpload(localId: String) async throws { try signedIn(); try uploads.enqueue(localId,automatic:false) }
    func deleteLocal(localId: String) async throws {
        try signedIn()
        guard uploads.activeId != localId,!(phone.active && phone.id == localId) else { throw RuntimeFailure("RECORDING_BUSY","Wait for the current recording or upload to finish.") }
        let draft = try store.draft(localId); media.stop()
        let file = URL(fileURLWithPath:string(draft["path"])).standardizedFileURL
        let directory = try store.directory().standardizedFileURL
        guard file.deletingLastPathComponent() == directory else { throw RuntimeFailure("FILE_PATH","Invalid local recording path.") }
        try FileManager.default.removeItem(at:file)
        try FileManager.default.removeItem(at:directory.appendingPathComponent(localId + ".json"))
    }
    func importAudio() async throws -> String? { try signedIn(); return try await media.importAudio() }
    func platformCommand(command: String,jsonBody: String?) async throws -> String {
        let args = try jsonBody.map { try jsonObject(Data($0.utf8)) } ?? [:]
        return jsonString(try await personal.command(command,args))
    }
    func playback(action: PlaybackAction,mediaId: String,local: Bool,positionMs: Int64,speed: Double) async throws {
        try signedIn()
        guard !phone.active else { throw RuntimeFailure("RECORDING_ACTIVE","Finish the phone recording before playing audio.") }
        try await media.playback(action,id:mediaId,local:local,position:positionMs,rate:speed)
    }
    func shareExport(recordingId: String,format: String) async throws { try signedIn(); try await media.shareExport(id:recordingId,format:format) }
    func shareText(text: String) async throws { try media.shareText(text) }
}

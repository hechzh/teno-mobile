import Foundation
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import LocalAuthentication

@MainActor final class NativeMedia: NSObject, UIDocumentPickerDelegate, AVAudioPlayerDelegate {
    private let store: NativeStore, api: SessionTransport
    private let saved: (String) -> Void
    weak var presenter: UIViewController?
    private var pickerResult: CheckedContinuation<String?, Error>?
    private var pickerScope = ""
    private var player: AVAudioPlayer?
    private var generation = 0
    private var mediaId = "", error = "", speed = 1.0
    init(store: NativeStore, api: SessionTransport, saved: @escaping (String) -> Void) {
        self.store = store; self.api = api; self.saved = saved
    }
    private func front() throws -> UIViewController {
        guard var front = presenter else { throw RuntimeFailure("WINDOW","Open Teno to continue.") }
        while let presented = front.presentedViewController { front = presented }
        return front
    }
    func importAudio() async throws -> String? {
        guard pickerResult == nil else { throw RuntimeFailure("IMPORT_BUSY","An import is already open.") }
        let view = try front(); pickerScope = store.scope
        guard !pickerScope.isEmpty else { throw RuntimeFailure("SIGN_IN","Sign in before importing audio.") }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes:[.audio],asCopy:false)
        picker.delegate = self; picker.allowsMultipleSelection = false
        return try await withCheckedThrowingContinuation { result in pickerResult = result; view.present(picker,animated:true) }
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { pickerResult?.resume(returning:nil); pickerResult = nil }
    func documentPicker(_ controller: UIDocumentPickerViewController,didPickDocumentsAt urls: [URL]) {
        guard let selected = urls.first, let result = pickerResult else { return }
        pickerResult = nil; let owner = pickerScope
        Task {
            let access = selected.startAccessingSecurityScopedResource()
            defer { if access { selected.stopAccessingSecurityScopedResource() } }
            var destination: URL?
            do {
                guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED","Sign in to the original account before importing.") }
                let coordinator = NSFileCoordinator(), allowed = Set(["wav","m4a","mp3","aac","ogg","flac","mp4"])
                let ext = allowed.contains(selected.pathExtension.lowercased()) ? selected.pathExtension.lowercased() : "audio"
                var draft = try store.newDraft(selected.deletingPathExtension().lastPathComponent,ext:ext)
                let target = URL(fileURLWithPath:string(draft["path"])); destination = target
                var coordinationError: NSError?, copyError: Error?
                coordinator.coordinate(readingItemAt:selected,options:.withoutChanges,error:&coordinationError) { source in
                    do {
                        let values = try source.resourceValues(forKeys:[.fileSizeKey])
                        guard let size = values.fileSize,size > 0,size <= 250 * 1024 * 1024 else { throw RuntimeFailure("IMPORT_LIMIT","Choose an audio file up to 250 MiB.") }
                        try FileManager.default.copyItem(at:source,to:target)
                    } catch { copyError = error }
                }
                if let coordinationError { throw coordinationError }; if let copyError { throw copyError }
                let duration = try await AVURLAsset(url:target).load(.duration).seconds
                guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED","The account changed during import.") }
                guard duration.isFinite,duration >= 0.1,duration <= 7200 else { throw RuntimeFailure("IMPORT_DURATION","Choose a supported audio file up to 120 minutes.") }
                draft["duration_ms"] = Int64(duration * 1000)
                try store.save(draft); saved(string(draft["id"])); result.resume(returning:string(draft["id"]))
            } catch {
                if let destination { try? FileManager.default.removeItem(at:destination) }
                result.resume(throwing:error)
            }
        }
    }
    func playback(_ action: PlaybackAction,id: String,local: Bool,position: Int64,rate: Double) async throws {
        if action == .stop { stop(); return }
        if action == .pause { player?.pause(); return }
        if action == .speed { speed = min(2,max(0.5,rate)); player?.rate = Float(speed); return }
        if id != mediaId || player == nil {
            stop(); generation += 1; let attempt = generation, owner = store.scope
            mediaId = id
            do {
                var file: URL
                if local { file = URL(fileURLWithPath:string(try store.draft(id)["path"])) }
                else if let draft = store.drafts().first(where:{ string($0["recording_id"]) == id && FileManager.default.fileExists(atPath:string($0["path"])) }) {
                    file = URL(fileURLWithPath:string(draft["path"]))
                } else {
                    guard id.range(of:"^[A-Za-z0-9_-]+$",options:.regularExpression) != nil else { throw RuntimeFailure("MEDIA_ID","Invalid recording.") }
                    file = store.root.appendingPathComponent("playback/" + owner + "/" + id + ".wav")
                    if !FileManager.default.fileExists(atPath:file.path) { try await api.download("/api/v1/recordings/" + id + "/audio",destination:file) }
                }
                guard generation == attempt,owner == store.scope else { return }
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback,mode:.spokenAudio); try session.setActive(true)
                let audio = try AVAudioPlayer(contentsOf:file); audio.delegate = self; audio.enableRate = true
                audio.rate = Float(speed); audio.prepareToPlay(); player = audio
            } catch { self.error = "Audio could not be played. " + error.localizedDescription; throw error }
        }
        if action == .seek || position > 0 { player?.currentTime = min(player?.duration ?? 0,max(0,Double(position)/1000)) }
        if action != .seek { player?.play() }
    }
    func stop() { generation += 1; player?.stop(); player = nil; mediaId = ""; error = "" }
    func state() -> PlaybackState {
        PlaybackState(ready:player != nil,playing:player?.isPlaying ?? false,positionMs:Int64((player?.currentTime ?? 0)*1000),
            durationMs:Int64((player?.duration ?? 0)*1000),speed:speed,mediaId:mediaId,error:error)
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer,error: Error?) { self.error = "This audio could not be decoded."; self.player = nil }
    func shareExport(id: String,format: String) async throws {
        guard ["md","txt","json","audio"].contains(format),id.range(of:"^[A-Za-z0-9_-]+$",options:.regularExpression) != nil else { throw RuntimeFailure("EXPORT","Unsupported export format.") }
        let owner = store.scope
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("exports/" + UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file = folder.appendingPathComponent("Teno-" + id + "." + (format == "audio" ? "wav" : format))
        if format == "audio" { try await api.download("/api/v1/recordings/" + id + "/audio",destination:file) }
        else { let bytes = try await api.data("GET","/api/v1/recordings/" + id + "/exports?format=" + format); try bytes.write(to:file,options:.atomic) }
        guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED","The account changed.") }
        try share([file])
    }
    func shareText(_ text: String) throws { try share([text]) }
    private func share(_ items: [Any]) throws {
        let view = try front(), activity = UIActivityViewController(activityItems:items,applicationActivities:nil)
        activity.popoverPresentationController?.sourceView = view.view
        activity.popoverPresentationController?.sourceRect = CGRect(x:view.view.bounds.midX,y:view.view.bounds.maxY-80,width:1,height:1)
        view.present(activity,animated:true)
    }
    func showDeviceKey(_ id: String) async throws {
        let context = LAContext()
        let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"View the original key for your Teno recorder")
        guard ok else { throw RuntimeFailure("DEVICE_KEY","Device authentication was cancelled.") }
        let key = try store.deviceKey(id)
        guard !key.isEmpty else { throw RuntimeFailure("DEVICE_KEY","No device key is saved for this recorder.") }
        let alert = UIAlertController(title:"Device key backup",message:key + "\n\nKeep this private. Use the same key when connecting this recorder on another phone.",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Done",style:.default))
        try front().present(alert,animated:true)
        // Do not expose this value through Flutter, diagnostics or the clipboard.
    }
}

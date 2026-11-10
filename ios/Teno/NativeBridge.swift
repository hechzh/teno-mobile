import Foundation

/// Keep native errors actionable without exposing stack traces or request arguments.
@MainActor func bridgeOperation<T>(_ operation: () async throws -> T) async throws -> T {
    do { return try await operation() }
    catch let failure as RuntimeFailure { throw PigeonError(code:failure.code,message:failure.message,details:nil) }
    catch { throw PigeonError(code:"ACTION_FAILED",message:error.localizedDescription,details:nil) }
}

@MainActor final class NativeBridge: RuntimeHost {
    let runtime: NativeRuntime
    init(_ runtime: NativeRuntime) { self.runtime = runtime }
    func snapshot() async throws -> RuntimeState { try await bridgeOperation { try await runtime.snapshot() } }
    func login(server: String,username: String,password: String) async throws -> SessionState {
        try await bridgeOperation { try await runtime.login(server:server,username:username,password:password) }
    }
    func logout() async throws { try await bridgeOperation { try await runtime.logout() } }
    func request(method: String,path: String,jsonBody: String?) async throws -> String {
        try await bridgeOperation { try await runtime.request(method:method,path:path,jsonBody:jsonBody) }
    }
    func platformCommand(command: String,jsonBody: String?) async throws -> String {
        try await bridgeOperation { try await runtime.platformCommand(command:command,jsonBody:jsonBody) }
    }
    func configure(cloudUpload: Bool,wifiOnly: Bool,livePreview: Bool) async throws {
        try await bridgeOperation { try await runtime.configure(cloudUpload:cloudUpload,wifiOnly:wifiOnly,livePreview:livePreview) }
    }
    func startPhone(title: String) async throws -> String { try await bridgeOperation { try await runtime.startPhone(title:title) } }
    func controlPhone(action: PhoneAction) async throws { try await bridgeOperation { try await runtime.controlPhone(action:action) } }
    func controlDevice(action: DeviceAction,identifier: String,name: String) async throws {
        try await bridgeOperation { try await runtime.controlDevice(action:action,identifier:identifier,name:name) }
    }
    func bindDevice(identifier: String,name: String,key: String,createNew: Bool) async throws {
        try await bridgeOperation { try await runtime.bindDevice(identifier:identifier,name:name,key:key,createNew:createNew) }
    }
    func showDeviceKey() async throws { try await bridgeOperation { try await runtime.showDeviceKey() } }
    func saveNotes(localId: String,notes: String) async throws { try await bridgeOperation { try await runtime.saveNotes(localId:localId,notes:notes) } }
    func retryUpload(localId: String) async throws { try await bridgeOperation { try await runtime.retryUpload(localId:localId) } }
    func deleteLocal(localId: String) async throws { try await bridgeOperation { try await runtime.deleteLocal(localId:localId) } }
    func importAudio() async throws -> String? { try await bridgeOperation { try await runtime.importAudio() } }
    func playback(action: PlaybackAction,mediaId: String,local: Bool,positionMs: Int64,speed: Double) async throws {
        try await bridgeOperation { try await runtime.playback(action:action,mediaId:mediaId,local:local,positionMs:positionMs,speed:speed) }
    }
    func shareExport(recordingId: String,format: String) async throws { try await bridgeOperation { try await runtime.shareExport(recordingId:recordingId,format:format) } }
    func shareText(text: String) async throws { try await bridgeOperation { try await runtime.shareText(text:text) } }
}

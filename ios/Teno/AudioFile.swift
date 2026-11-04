import Foundation
import AVFoundation

/// The file header is repaired from committed PCM bytes after a process interruption.
final class PCMFile: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private(set) var bytes: Int64 = 0
    private var closed = false
    init(_ url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: Data(count: 44),
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }
    static func header(_ count: Int64) -> Data {
        var data = Data("RIFF".utf8)
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        u32(UInt32(count + 36)); data.append(Data("WAVEfmt ".utf8)); u32(16)
        u16(1); u16(1); u32(16000); u32(32000); u16(2); u16(16)
        data.append(Data("data".utf8)); u32(UInt32(count)); return data
    }
    func append(_ data: Data) throws -> Int64 {
        lock.lock(); defer { lock.unlock() }
        guard !closed, bytes + Int64(data.count) <= 54 * 60 * 32000 else {
            throw RuntimeFailure("RECORDING_LIMIT", "Recording stopped at the 54-minute local limit.")
        }
        try handle.write(contentsOf: data); bytes += Int64(data.count)
        return bytes
    }
    func finish() throws -> Int64 {
        lock.lock(); defer { lock.unlock() }
        if !closed {
            try handle.seek(toOffset: 0); try handle.write(contentsOf: Self.header(bytes))
            try handle.synchronize(); try handle.close(); closed = true
        }
        return bytes
    }
    static func recover(_ url: URL) throws -> Int64 {
        let handle = try FileHandle(forUpdating: url); defer { try? handle.close() }
        let length = Int64(try handle.seekToEnd())
        guard length > 44 else { throw RuntimeFailure("EMPTY_AUDIO", "No complete audio was saved.") }
        let count = (length - 44) / 2 * 2
        try handle.truncate(atOffset: UInt64(44 + count)); try handle.seek(toOffset: 0)
        try handle.write(contentsOf: header(count)); try handle.synchronize(); return count
    }
}

@MainActor final class PhoneRecorder {
    private let store: NativeStore
    private let api: SessionTransport
    private let saved: (String) -> Void
    private var engine: AVAudioEngine?
    private var file: PCMFile?
    private var interruption: NSObjectProtocol?
    private var routeChange: NSObjectProtocol?
    var preview: LivePreview?
    private(set) var id = "", phase = "idle", status = "Ready"
    private(set) var elapsed: Int64 = 0
    var active: Bool { ["starting", "recording", "paused", "saving"].contains(phase) }
    init(store: NativeStore, api: SessionTransport, saved: @escaping (String) -> Void) {
        self.store = store; self.api = api; self.saved = saved
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] event in
            guard let kind = event.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  kind == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.pause(reason: "Recording paused by iOS. Resume when ready.") }
        }
        routeChange = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] event in
            guard let reason = event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.pause(reason: "Audio input changed. Resume when ready.") }
        }
        recover()
    }
    private func recover() {
        for var draft in store.drafts() where string(draft["status"]) == "recording" {
            do {
                let bytes = try PCMFile.recover(URL(fileURLWithPath: string(draft["path"])))
                draft["duration_ms"] = bytes / 32; draft["status"] = "local"
                draft["error"] = "Recovered after an interruption. Check the audio before uploading."
                try store.save(draft)
            } catch { draft["status"] = "invalid"; draft["error"] = "Interrupted recording has no complete audio."; try? store.save(draft) }
        }
    }
    func start(_ title: String) async throws -> String {
        guard !active else { throw RuntimeFailure("CAPTURE_BUSY", "Finish the current recording first.") }
        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { continuation in session.requestRecordPermission { continuation.resume(returning: $0) } }
        guard granted else { throw RuntimeFailure("MICROPHONE_PERMISSION", "Allow microphone access in iOS Settings to record on this phone.") }
        var draft = try store.newDraft(title.isEmpty ? "New recording" : title, ext: "wav")
        id = string(draft["id"]); elapsed = 0; phase = "starting"; status = "Starting microphone"
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(16000); try session.setActive(true)
            let audioEngine = AVAudioEngine(), input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0,
                  let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true),
                  let converter = AVAudioConverter(from: format, to: target) else {
                throw RuntimeFailure("MICROPHONE_FORMAT", "This audio input is unavailable.")
            }
            let writer = try PCMFile(URL(fileURLWithPath: string(draft["path"])))
            draft["status"] = "recording"; try store.save(draft)
            file = writer; engine = audioEngine
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / format.sampleRate) + 32)
                guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
                var supplied = false, error: NSError?
                let result = converter.convert(to: output, error: &error) { _, state in
                    if supplied { state.pointee = .noDataNow; return nil }
                    supplied = true; state.pointee = .haveData; return buffer
                }
                guard error == nil, result != .error, let samples = output.int16ChannelData, output.frameLength > 0 else {
                    Task { @MainActor in try? self?.stop(reason: "Audio input failed. The saved portion is kept.") }; return
                }
                let bytes = Data(bytes: samples[0], count: Int(output.frameLength) * 2)
                do {
                    let total = try writer.append(bytes)
                    Task { @MainActor in self?.elapsed = total / 32; self?.preview?.feed(bytes) }
                } catch {
                    Task { @MainActor in try? self?.stop(reason: error.localizedDescription) }
                }
            }
            audioEngine.prepare(); try audioEngine.start()
            if store.livePreview { preview = LivePreview(api: api, id: id, title: title) }
            phase = "recording"; status = "Recording · Audio saved locally"; return id
        } catch {
            engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
            _ = try? file?.finish(); file = nil; phase = "idle"; status = error.localizedDescription
            draft["status"] = "invalid"; draft["error"] = status; try? store.save(draft)
            try? session.setActive(false, options: .notifyOthersOnDeactivation); throw error
        }
    }
    func pause(reason: String = "Recording paused") {
        guard phase == "recording" else { return }
        engine?.pause(); phase = "paused"; status = reason; preview?.pause(true)
    }
    func resume() throws {
        guard phase == "paused" else { return }
        try AVAudioSession.sharedInstance().setActive(true); try engine?.start()
        phase = "recording"; status = "Recording · Audio saved locally"; preview?.pause(false)
    }
    func stop(reason: String = "Saved on this phone") throws {
        guard active else { return }
        phase = "saving"; engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
        preview?.finish()
        let count = try file?.finish() ?? 0; file = nil
        var draft = try store.draft(id)
        draft["duration_ms"] = count / 32; draft["status"] = count > 0 ? "local" : "invalid"
        if count == 0 { draft["error"] = "No complete audio was recorded." }
        try store.save(draft); elapsed = count / 32; phase = "idle"; status = reason
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if count > 0 { saved(id) }
    }
}

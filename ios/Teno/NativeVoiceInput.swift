import Foundation
import UIKit
import AVFoundation

@MainActor final class NativeVoiceInput: NSObject, AVAudioRecorderDelegate {
    unowned let runtime: NativeRuntime
    private var recorder: AVAudioRecorder?, file: URL?, dialog: UIAlertController?
    private var continuation: CheckedContinuation<JSONObject,Error>?
    private var owner = ""
    init(runtime: NativeRuntime) { self.runtime = runtime }
    private func label(_ en: String,_ zh: String) -> String {
        let language = runtime.store.preferences.string(forKey:"interface_locale") ?? "system"
        return language == "zh" || language == "system" && Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    func start() async throws -> JSONObject {
        guard continuation == nil, let presenter = runtime.media.presenter else { throw RuntimeFailure("VOICE_BUSY", "Finish the current voice input first.") }
        let permission = await withCheckedContinuation { result in AVAudioSession.sharedInstance().requestRecordPermission { result.resume(returning:$0) } }
        guard permission else { throw RuntimeFailure("MICROPHONE_PERMISSION", "Allow microphone access in Settings.") }
        owner = runtime.store.scope; runtime.media.stop()
        let folder = runtime.store.root.appendingPathComponent("voice",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let target = folder.appendingPathComponent(UUID().uuidString + ".m4a"); file = target
        let audio = AVAudioSession.sharedInstance(); try audio.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker]); try audio.setActive(true)
        let capture = try AVAudioRecorder(url:target,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:16000,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:64000])
        capture.delegate = self; recorder = capture
        guard capture.record(forDuration:60) else { throw RuntimeFailure("MICROPHONE", "Voice input could not start.") }
        return try await withCheckedThrowingContinuation { result in
            continuation = result
            let alert = UIAlertController(title:label("Speak your question","请说出你的问题"),message:label("Up to 60 seconds. You can edit the text before sending.","最长 60 秒，发送前可以编辑文字。"),preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:label("Stop","停止"),style:.default) { [weak self] _ in self?.finish(save:true) })
            alert.addAction(UIAlertAction(title:label("Cancel","取消"),style:.cancel) { [weak self] _ in self?.finish(save:false) })
            dialog = alert; presenter.present(alert,animated:true)
        }
    }
    func cancel() { finish(save:false) }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) { finish(save:flag) }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) { finish(save:false) }
    private func finish(save: Bool) {
        guard let result = continuation else { return }; continuation = nil
        recorder?.stop(); recorder = nil; dialog?.dismiss(animated:true); dialog = nil
        let target = file, scope = owner; file = nil
        Task {
            defer { if let target { try? FileManager.default.removeItem(at:target) } }
            do {
                guard save, let target else { result.resume(returning:["text":""]); return }
                guard scope == runtime.store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
                let value = try await runtime.api.uploadSmall("/api/v1/personal/dictation",file:target,filename:"question.m4a")
                guard scope == runtime.store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
                result.resume(returning:value)
            } catch { result.resume(throwing:error) }
        }
    }
}

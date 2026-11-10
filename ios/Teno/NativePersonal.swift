import Foundation
import UIKit
import EventKit
import LocalAuthentication
import UserNotifications
import QuickLook

/// Native services behind the same personal-library UI used by Android.
@MainActor final class NativePersonal: NSObject, QLPreviewControllerDataSource {
    unowned let runtime: NativeRuntime
    private let events = EKEventStore()
    private var previewFiles: [URL] = []
    private var privacyCover: UIView?
    private var authenticating = false
    lazy var importer = NativeImportCoordinator(store: runtime.store, uploads: runtime.uploads, presenter: { [weak self] in self?.runtime.media.presenter })
    lazy var voice = NativeVoiceInput(runtime: runtime)
    init(_ runtime: NativeRuntime) { self.runtime = runtime }
    private var store: NativeStore { runtime.store }
    private func key(_ name: String) -> String { "personal." + store.scope + "." + name }
    private func signedIn() throws {
        guard store.state().signedIn else { throw RuntimeFailure("SIGN_IN", "Sign in to continue.") }
    }
    private var exportDirectory: URL {
        store.root.appendingPathComponent("exports", isDirectory: true).appendingPathComponent(store.scope.isEmpty ? "signed-out" : store.scope, isDirectory: true)
    }
    private var cacheDirectories: [URL] {
        [exportDirectory,store.root.appendingPathComponent("playback",isDirectory:true).appendingPathComponent(store.scope,isDirectory:true)]
    }
    func command(_ command: String, _ args: JSONObject) async throws -> JSONObject {
        if command == "interface_locale" {
            if let locale = args["locale"] as? String {
                guard ["system","en","zh"].contains(locale) else { throw RuntimeFailure("LANGUAGE", "Invalid interface language.") }
                store.preferences.set(locale, forKey: "interface_locale")
            }
            return ["locale":store.preferences.string(forKey:"interface_locale") ?? "system"]
        }
        if command == "preferences" {
            let settings = store.preferences.data(forKey:key("settings")).flatMap { try? jsonObject($0) } ?? [:]
            return ["personal_core":true,"settings":settings,"app_lock":store.preferences.bool(forKey:key("lock")),"pending_imports":importer.pendingItems().count]
        }
        if command == "pending_imports" { return ["items":importer.pendingItems()] }
        if command == "discard_imports" { try importer.discardPending(); return [:] }
        try signedIn()
        switch command {
        case "cache_preferences": store.preferences.set(try jsonData(args), forKey:key("settings")); return [:]
        case "history":
            var values = store.preferences.stringArray(forKey:key("history")) ?? []
            if args["clear"] as? Bool == true { values = [] }
            else {
                let query = string(args["query"]).trimmingCharacters(in:.whitespacesAndNewlines)
                if !query.isEmpty { values.removeAll { $0 == query }; values.insert(query,at:0) }
            }
            values = Array(values.prefix(10)); store.preferences.set(values,forKey:key("history")); return ["items":values]
        case "storage":
            let bytes = store.drafts().reduce(Int64(0)) { $0 + fileSize(URL(fileURLWithPath:string($1["path"]))) }
            return ["local_bytes":bytes,"cache_bytes":cacheDirectories.reduce(Int64(0)) { $0 + directorySize($1) }]
        case "clear_cache":
            runtime.media.stop(); let bytes = cacheDirectories.reduce(Int64(0)) { $0 + directorySize($1) }
            for folder in cacheDirectories where FileManager.default.fileExists(atPath:folder.path) { try FileManager.default.removeItem(at:folder) }
            return ["bytes":bytes]
        case "notifications":
            let enabled = args["enabled"] as? Bool ?? false
            if enabled { _ = try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge]) }
            store.preferences.set(enabled,forKey:key("notifications")); return ["enabled":enabled]
        case "app_lock":
            let enabled = args["enabled"] as? Bool ?? false
            if enabled {
                guard try await LAContext().evaluatePolicy(.deviceOwnerAuthentication,localizedReason:label("Unlock Teno","解锁 Teno")) else { throw RuntimeFailure("APP_LOCK", "Device authentication was cancelled.") }
            }
            store.preferences.set(enabled,forKey:key("lock")); return ["enabled":enabled]
        case "calendar": return try await readCalendar()
        case "import", "photo":
            return try await importer.open(source:command == "photo" ? "camera" : string(args["source"]), parent:command == "photo" ? string(args["local_id"] ?? args["id"]) : "", atMs:(args["at_ms"] as? NSNumber)?.int64Value ?? 0)
        case "accept_imports": return try await importer.acceptPending()
        case "dictate":
            guard !runtime.phone.active else { throw RuntimeFailure("CAPTURE_ACTIVE", "Finish the recording before using voice input.") }
            return try await voice.start()
        case "cancelUpload": await runtime.uploads.cancel(string(args["id"])); return [:]
        case "local_export":
            let draft = try store.draft(string(args["id"]))
            let file = URL(fileURLWithPath:string(draft["path"])).standardizedFileURL
            guard file.deletingLastPathComponent() == (try store.directory()).standardizedFileURL else { throw RuntimeFailure("FILE_PATH", "Invalid local file path.") }
            try runtime.media.shareFiles([file]); return [:]
        case "export", "preview":
            let owner = store.scope, path = string(args["path"]), format = string(args["format"])
            guard format.range(of:"^[a-z0-9]{1,8}$",options:.regularExpression) != nil else { throw RuntimeFailure("EXPORT_FORMAT", "Choose a supported export format.") }
            let bytes = try await runtime.api.data("GET",path)
            guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
            try FileManager.default.createDirectory(at:exportDirectory,withIntermediateDirectories:true)
            let file = exportDirectory.appendingPathComponent(UUID().uuidString + "." + format)
            try bytes.write(to:file,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            if command == "preview", QLPreviewController.canPreview(file as NSURL) {
                previewFiles = [file]; let controller = QLPreviewController(); controller.dataSource = self
                try front().present(controller,animated:true)
            } else { try runtime.media.shareFiles([file]) }
            return [:]
        default: throw RuntimeFailure("UNSUPPORTED_ACTION", "This action is not available.")
        }
    }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewFiles.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { previewFiles[index] as NSURL }
    private func front() throws -> UIViewController {
        guard var controller = runtime.media.presenter else { throw RuntimeFailure("WINDOW", "Open Teno to continue.") }
        while let shown = controller.presentedViewController { controller = shown }
        return controller
    }
    private func readCalendar() async throws -> JSONObject {
        let granted: Bool
        if #available(iOS 17.0, *) { granted = try await events.requestFullAccessToEvents() }
        else { granted = try await events.requestAccess(to:.event) }
        guard granted else { throw RuntimeFailure("CALENDAR_PERMISSION", "Calendar permission is required. You can add an event manually.") }
        let start = Date().addingTimeInterval(-86400), end = Date().addingTimeInterval(30 * 86400)
        let predicate = events.predicateForEvents(withStart:start,end:end,calendars:nil)
        let formatter = ISO8601DateFormatter()
        return ["events":events.events(matching:predicate).prefix(200).map { event in
            ["native_id":(event.eventIdentifier ?? UUID().uuidString) + ":" + formatter.string(from:event.startDate),
             "title":event.title ?? "", "starts_at":formatter.string(from:event.startDate), "ends_at":formatter.string(from:event.endDate)]
        }]
    }
    private func fileSize(_ file: URL) -> Int64 { (try? file.resourceValues(forKeys:[.fileSizeKey]).fileSize).map(Int64.init) ?? 0 }
    private func directorySize(_ folder: URL) -> Int64 {
        guard let files = FileManager.default.enumerator(at:folder,includingPropertiesForKeys:[.isRegularFileKey,.fileSizeKey]) else { return 0 }
        return files.compactMap { $0 as? URL }.reduce(Int64(0)) { $0 + fileSize($1) }
    }
    private func label(_ en: String, _ zh: String) -> String {
        let preference = store.preferences.string(forKey:"interface_locale") ?? "system"
        return preference == "zh" || preference == "system" && Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    func lockForBackground() {
        guard store.state().signedIn, store.preferences.bool(forKey:key("lock")), privacyCover == nil, let view = runtime.media.presenter?.view else { return }
        let cover = UIView(frame:view.bounds); cover.autoresizingMask = [.flexibleWidth,.flexibleHeight]; cover.backgroundColor = UIColor(red:0.984,green:0.98,blue:0.965,alpha:1)
        let button = UIButton(type:.system); button.setTitle(label("Unlock Teno","解锁 Teno"),for:.normal)
        button.addTarget(self,action:#selector(unlockPressed),for:.touchUpInside); button.frame = CGRect(x:40,y:view.bounds.midY-28,width:view.bounds.width-80,height:56); button.autoresizingMask = [.flexibleWidth,.flexibleTopMargin,.flexibleBottomMargin]
        cover.addSubview(button); view.addSubview(cover); privacyCover = cover
    }
    @objc private func unlockPressed() { authenticateIfNeeded() }
    func authenticateIfNeeded() {
        guard privacyCover != nil, !authenticating else { return }
        authenticating = true
        Task {
            defer { authenticating = false }
            if (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication,localizedReason:label("Unlock Teno","解锁 Teno"))) == true {
                privacyCover?.removeFromSuperview(); privacyCover = nil
            }
        }
    }
    func cancelAccountUI() {
        voice.cancel(); importer.cancel(); previewFiles = []; privacyCover?.removeFromSuperview(); privacyCover = nil
        if runtime.media.presenter?.presentedViewController is QLPreviewController { runtime.media.presenter?.dismiss(animated:false) }
    }
}

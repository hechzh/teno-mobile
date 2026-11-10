import Foundation
import UIKit
import Network
import UserNotifications

/// Background URLSession owns transfers. Draft JSON is the durable source of truth.
@MainActor final class UploadQueue: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let backgroundIdentifier = (Bundle.main.bundleIdentifier ?? "com.jwd.ZhiYan") + ".uploads"
    let store: NativeStore
    let api: SessionTransport
    private var responses: [Int: Data] = [:]
    private var pumping = false
    private var retry: Task<Void, Never>?
    private var restored = false
    private var paused = false
    private var generation = 0
    private var monitor = NWPathMonitor()
    private var hasNetwork = false, hasWifi = false
    private(set) var activeId = "", status = ""
    var backgroundCompletion: (() -> Void)?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundIdentifier)
        config.sessionSendsLaunchEvents = true; config.isDiscretionary = false
        config.timeoutIntervalForResource = 60 * 60
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    init(store: NativeStore, api: SessionTransport) {
        self.store = store; self.api = api; super.init()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.hasNetwork = path.status == .satisfied
                self?.hasWifi = path.usesInterfaceType(.wifi)
                self?.resume()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.teno.network"))
        Task {
            let tasks = await session.allTasks
            for task in tasks {
                guard let info = metadata(task), string(info["scope"]) == store.scope else { task.cancel(); continue }
                activeId = string(info["id"])
            }
            if tasks.isEmpty {
                for var draft in store.drafts() where string(draft["status"]) == "uploading" {
                    draft["status"] = "queued"; try? store.save(draft)
                }
            }
            restored = true; resume()
        }
    }
    func saved(_ id: String) {
        if store.cloudUpload { try? enqueue(id, automatic: true) }
    }
    func enqueue(_ id: String, automatic: Bool) throws {
        var draft = try store.draft(id)
        guard !Self.remote(draft) else { return }
        guard !["recording", "invalid"].contains(string(draft["status"])),
              FileManager.default.fileExists(atPath: string(draft["path"])) else {
            throw RuntimeFailure("INVALID_AUDIO", "No complete audio is available to upload.")
        }
        if id == activeId { return }
        draft["upload_requested"] = true; draft["upload_automatic"] = automatic
        draft["upload_attempts"] = 0; draft["upload_retry_at"] = 0; draft["status"] = "queued"
        draft.removeValue(forKey: "error"); try store.save(draft); resume()
    }
    private func requested(_ draft: JSONObject) -> Bool {
        draft["upload_requested"] as? Bool == true && !Self.remote(draft) &&
            (draft["upload_automatic"] as? Bool != true || store.cloudUpload) &&
            (string(draft["parent_local_id"]).isEmpty || !parentRecording(draft).isEmpty)
    }
    func resume() {
        guard restored, !paused, !pumping, activeId.isEmpty, store.state().signedIn, hasNetwork,
              !store.wifiOnly || hasWifi else { return }
        let drafts = store.drafts().reversed().filter(requested)
        guard let next = drafts.first else { return }
        let now = Date().timeIntervalSince1970
        let after = next["upload_retry_at"] as? Double ?? 0
        if after > now {
            retry?.cancel(); retry = Task { try? await Task.sleep(nanoseconds: UInt64(min(after-now, 3600) * 1_000_000_000)); if !Task.isCancelled { resume() } }; return
        }
        pumping = true
        let attemptGeneration = generation
        Task {
            defer { pumping = false; resume() }
            let id = string(next["id"]), owner = store.scope
            do {
                var attempting = try store.draft(id)
                attempting["upload_attempts"] = (attempting["upload_attempts"] as? Int ?? 0) + 1
                try store.save(attempting)
                // Refresh before creating the OS-owned upload task. Refreshes are serialized.
                let old = try store.token("access_token")
                try await api.refresh(after: old)
                guard owner == store.scope, attemptGeneration == generation, !paused else { return }
                guard let current = try? store.draft(id), requested(current) else { return }
                let payload = try multipart(current)
                var request = try api.makeRequest("POST", string(next["kind"]) == "file" ? "/api/v1/files" : "/api/v1/recordings")
                request.setValue("multipart/form-data; boundary=" + payload.boundary, forHTTPHeaderField: "Content-Type")
                request.allowsCellularAccess = !store.wifiOnly
                request.allowsExpensiveNetworkAccess = !store.wifiOnly
                var draft = try store.draft(id)
                draft["status"] = "uploading"
                try store.save(draft)
                let task = session.uploadTask(with: request, fromFile: payload.file)
                task.taskDescription = jsonString(["id": id, "scope": owner, "payload": payload.file.lastPathComponent])
                activeId = id; status = "Uploading · Local copy kept"; task.resume()
            } catch {
                if attemptGeneration == generation, !paused { failed(id, owner: owner, message: error.localizedDescription, retryable: true) }
            }
        }
    }
    static func remote(_ draft: JSONObject) -> Bool { !string(draft["recording_id"]).isEmpty || !string(draft["file_id"]).isEmpty }
    func parentRecording(_ draft: JSONObject) -> String {
        let remote = string(draft["recording_id_parent"]), parent = string(draft["parent_local_id"])
        if !remote.isEmpty { return remote }
        if parent.hasPrefix("jwd:") {
            let parts = parent.dropFirst(4).split(separator:"|",maxSplits:1).map(String.init)
            guard parts.count == 2 else { return "" }
            return store.drafts().first { string($0["jwd_device"]) == parts[0] && string($0["jwd_file"]) == parts[1] }.map { string($0["recording_id"]) } ?? ""
        }
        return (try? store.draft(parent)).map { string($0["recording_id"]) } ?? ""
    }
    func fields(_ draft: JSONObject) -> [(String,String)] {
        var values = [("client_id",string(draft["id"]))]
        if string(draft["kind"]) == "file" {
            let parent = parentRecording(draft)
            if !parent.isEmpty { values.append(("recording_id",parent)) }
            if let position = draft["at_ms"] as? NSNumber { values.append(("at_ms",position.stringValue)) }
        } else {
            values += [("title",string(draft["title"])),("language","auto"),("personal_mode","true"),("source",string(draft["source"]) == "import" ? "import" : string(draft["source"]) == "jwd_ble" ? "device" : "phone")]
            if !string(draft["live_session_id"]).isEmpty { values.append(("live_session_id",string(draft["live_session_id"]))) }
        }
        return values
    }
    private func safeFilename(_ value: String) -> String {
        value.replacingOccurrences(of:"\"",with:"_").replacingOccurrences(of:"\r",with:"_").replacingOccurrences(of:"\n",with:"_").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"\\",with:"_")
    }
    func cancel(_ id: String) async {
        guard var draft = try? store.draft(id), !Self.remote(draft) else { return }
        draft["upload_requested"] = false; draft["status"] = "local"; draft.removeValue(forKey:"error"); try? store.save(draft)
        for task in await session.allTasks where metadata(task).map({ string($0["scope"]) == store.scope && string($0["id"]) == id }) == true { task.cancel() }
        if activeId == id { activeId = ""; status = "Local copy kept" }
        resume()
    }
    func processingRetry(_ path: String, result: JSONObject) {
        let recording = string(result["recording_id"])
        let file = path.hasPrefix("/api/v1/files/") ? String(path.dropFirst("/api/v1/files/".count).dropLast("/retry".count)) : ""
        for var draft in store.drafts() where (!recording.isEmpty && recording == string(draft["recording_id"])) || (!file.isEmpty && file == string(draft["file_id"])) {
            draft["status"] = "processing"; draft["ready_notified"] = false; draft.removeValue(forKey:"error"); try? store.save(draft)
        }
    }
    private var checkingProcessing = false
    private var lastProcessingCheck = Date.distantPast
    func pollProcessing() async {
        guard !paused, !checkingProcessing, hasNetwork, store.state().signedIn, Date().timeIntervalSince(lastProcessingCheck) >= 15 else { return }
        checkingProcessing = true; lastProcessingCheck = Date(); let owner = store.scope
        defer { checkingProcessing = false }
        for item in store.drafts() where Self.remote(item) && item["ready_notified"] as? Bool != true {
            guard owner == store.scope, !paused else { return }
            do {
                let file = !string(item["file_id"]).isEmpty
                let state = try await api.json("GET",file ? "/api/v1/files/" + string(item["file_id"]) : "/api/v1/personal/recordings/" + string(item["recording_id"]) + "/processing")
                guard owner == store.scope, ["ready","failed"].contains(string(state["status"])), var draft = try? store.draft(string(item["id"])) else { continue }
                let failed = string(state["status"]) == "failed"
                draft["status"] = failed ? "processing_failed" : "ready"; draft["ready_notified"] = true
                if failed { draft["error"] = string((state["error"] as? JSONObject)?["message"]) }
                else { draft.removeValue(forKey:"error"); draft["processing_message"] = string(state["message"]) }
                try store.save(draft)
                if store.preferences.object(forKey:"personal." + owner + ".notifications") as? Bool != false {
                    let content = UNMutableNotificationContent(); content.title = failed ? "Teno · Processing needs attention" : "Teno · Ready"; content.body = string(draft["title"])
                    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:string(draft["id"]),content:content,trigger:nil))
                }
            } catch { /* A later foreground check retries without creating any generation jobs. */ }
        }
    }
    /// Called before credentials change; completion from old tasks can never write to a new scope.
    func pauseAccount() async {
        paused = true; generation += 1
        retry?.cancel()
        for task in await session.allTasks { task.cancel() }
        for var draft in store.drafts() where string(draft["status"]) == "uploading" {
            draft["status"] = "queued"; try? store.save(draft)
        }
        activeId = ""; status = ""
    }
    func resumeAccount() { paused = false; resume() }
    private func multipart(_ draft: JSONObject) throws -> (file: URL, boundary: String) {
        let boundary = "Teno-" + UUID().uuidString
        let folder = store.root.appendingPathComponent("uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(UUID().uuidString + ".body")
        FileManager.default.createFile(atPath: file.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let out = try FileHandle(forWritingTo: file); defer { try? out.close() }
        func write(_ value: String) throws { try out.write(contentsOf: Data(value.utf8)) }
        for (name,value) in fields(draft) {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        let source = URL(fileURLWithPath: string(draft["path"]))
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename(string(draft["filename"]).isEmpty ? string(draft["title"]) + "." + source.pathExtension : string(draft["filename"])))\"\r\nContent-Type: application/octet-stream\r\n\r\n")
        let input = try FileHandle(forReadingFrom: source); defer { try? input.close() }
        while let bytes = try input.read(upToCount: 256 * 1024), !bytes.isEmpty { try out.write(contentsOf: bytes) }
        try write("\r\n--\(boundary)--\r\n"); try out.synchronize()
        return (file,boundary)
    }
    private func metadata(_ task: URLSessionTask) -> JSONObject? {
        guard let text = task.taskDescription, let bytes = text.data(using: .utf8) else { return nil }
        return try? jsonObject(bytes)
    }
    private func failed(_ id: String, owner: String, message: String, retryable: Bool) {
        guard owner == store.scope, var draft = try? store.draft(id), !Self.remote(draft) else { return }
        let attempts = draft["upload_attempts"] as? Int ?? 0
        let again = retryable && attempts < 3
        draft["upload_requested"] = again; draft["status"] = again ? "queued" : "failed"; draft["error"] = message
        draft["upload_retry_at"] = Date().timeIntervalSince1970 + pow(2, Double(min(attempts,3))) * 30
        try? store.save(draft); status = "Upload paused · Local copy kept"
        retry?.cancel(); retry = Task { try? await Task.sleep(nanoseconds: 2_000_000_000); if !Task.isCancelled { resume() } }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Server response is a small JSON result, never audio.
        if (responses[dataTask.taskIdentifier]?.count ?? 0) + data.count < 1_000_000 {
            responses[dataTask.taskIdentifier, default: Data()].append(data)
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard metadata(task).map({ string($0["scope"]) == store.scope }) == true else { return }
        status = "Uploading \(totalBytesExpectedToSend > 0 ? totalBytesSent * 100 / totalBytesExpectedToSend : 0)%"
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let bytes = responses.removeValue(forKey: task.taskIdentifier) ?? Data()
        guard let info = metadata(task) else { return }
        let owner = string(info["scope"]), id = string(info["id"])
        let file = store.root.appendingPathComponent("uploads").appendingPathComponent(string(info["payload"]))
        try? FileManager.default.removeItem(at: file)
        guard owner == store.scope else { return }
        if activeId == id { activeId = "" }
        if (error as NSError?)?.code == NSURLErrorCancelled { return }
        do {
            if let error { throw error }
            guard let response = task.response else { throw RuntimeFailure("UPLOAD", "No upload response received.") }
            try api.validate(response, data: bytes)
            let result = try jsonObject(bytes)
            var draft = try store.draft(id)
            let remoteKey = string(draft["kind"]) == "file" ? "file_id" : "recording_id"
            guard !string(result[remoteKey]).isEmpty else { throw RuntimeFailure("UPLOAD", "Invalid upload response. Retry safely with the same file ID.") }
            draft[remoteKey] = result[remoteKey]; draft["job_id"] = string(result["job_id"])
            draft["status"] = string(result["job_id"]).isEmpty ? "uploaded" : "processing"; draft["upload_requested"] = false
            try store.save(draft); status = "Processing recording · Local copy kept"
            Task { await uploadNotes(draft, owner: owner); resume() }
        } catch {
            let code = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            failed(id, owner: owner, message: error.localizedDescription,
                retryable: code == 0 || code == 401 || code == 408 || code == 429 || code >= 500)
        }
    }
    private func uploadNotes(_ draft: JSONObject, owner: String) async {
        let note = string(draft["notes"])
        guard !string(draft["recording_id"]).isEmpty, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, owner == store.scope else { return }
        do {
            let boundary = "Teno-" + UUID().uuidString
            var request = try api.makeRequest("POST", "/api/v1/recordings/" + string(draft["recording_id"]) + "/attachments")
            request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"Recording-notes.md\"\r\nContent-Type: text/markdown\r\n\r\n\(note)\r\n--\(boundary)--\r\n".utf8)
            let (bytes,response) = try await URLSession.shared.data(for: request)
            try api.validate(response, data: bytes)
        } catch {
            if owner == store.scope, var saved = try? store.draft(string(draft["id"])) {
                saved["note_error"] = "Audio uploaded. Recording notes remain on this phone."; try? store.save(saved)
            }
        }
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundCompletion?(); backgroundCompletion = nil
    }
}

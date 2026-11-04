import Foundation
import UIKit
import Network

/// Background URLSession owns transfers. Draft JSON is the durable source of truth.
@MainActor final class UploadQueue: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    let store: NativeStore
    let api: SessionTransport
    private var responses: [Int: Data] = [:]
    private var pumping = false
    private var retry: Task<Void, Never>?
    private var restored = false
    private var monitor = NWPathMonitor()
    private var hasNetwork = false, hasWifi = false
    private(set) var activeId = "", status = ""
    var backgroundCompletion: (() -> Void)?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.teno.app.uploads")
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
        guard string(draft["recording_id"]).isEmpty else { return }
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
        draft["upload_requested"] as? Bool == true && string(draft["recording_id"]).isEmpty &&
            (draft["upload_automatic"] as? Bool != true || store.cloudUpload)
    }
    func resume() {
        guard restored, !pumping, activeId.isEmpty, store.state().signedIn, hasNetwork,
              !store.wifiOnly || hasWifi else { return }
        let drafts = store.drafts().reversed().filter(requested)
        guard let next = drafts.first else { return }
        let now = Date().timeIntervalSince1970
        let after = next["upload_retry_at"] as? Double ?? 0
        if after > now {
            retry?.cancel(); retry = Task { try? await Task.sleep(nanoseconds: UInt64(min(after-now, 3600) * 1_000_000_000)); if !Task.isCancelled { resume() } }; return
        }
        pumping = true
        Task {
            defer { pumping = false }
            let id = string(next["id"]), owner = store.scope
            do {
                // Refresh before creating the OS-owned upload task. Refreshes are serialized.
                let old = try store.token("access_token")
                try await api.refresh(after: old)
                guard owner == store.scope else { return }
                let payload = try multipart(next)
                var request = try api.makeRequest("POST", "/api/v1/recordings")
                request.setValue("multipart/form-data; boundary=" + payload.boundary, forHTTPHeaderField: "Content-Type")
                request.allowsCellularAccess = !store.wifiOnly
                request.allowsExpensiveNetworkAccess = !store.wifiOnly
                var draft = try store.draft(id)
                draft["status"] = "uploading"; draft["upload_attempts"] = (draft["upload_attempts"] as? Int ?? 0) + 1
                try store.save(draft)
                let task = session.uploadTask(with: request, fromFile: payload.file)
                task.taskDescription = jsonString(["id": id, "scope": owner, "payload": payload.file.lastPathComponent])
                activeId = id; status = "Uploading · Local copy kept"; task.resume()
            } catch { failed(id, owner: owner, message: error.localizedDescription, retryable: true) }
        }
    }
    /// Called before credentials change; completion from old tasks can never write to a new scope.
    func pauseAccount() async {
        retry?.cancel()
        for task in await session.allTasks { task.cancel() }
        for var draft in store.drafts() where string(draft["status"]) == "uploading" {
            draft["status"] = "queued"; try? store.save(draft)
        }
        activeId = ""; status = ""
    }
    private func multipart(_ draft: JSONObject) throws -> (file: URL, boundary: String) {
        let boundary = "Teno-" + UUID().uuidString
        let folder = store.root.appendingPathComponent("uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(UUID().uuidString + ".body")
        FileManager.default.createFile(atPath: file.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let out = try FileHandle(forWritingTo: file); defer { try? out.close() }
        func write(_ value: String) throws { try out.write(contentsOf: Data(value.utf8)) }
        for (name,value) in [("client_id",string(draft["id"])),("title",string(draft["title"])),("language","auto")] {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        let source = URL(fileURLWithPath: string(draft["path"]))
        try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.\(source.pathExtension)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
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
        guard owner == store.scope, var draft = try? store.draft(id), string(draft["recording_id"]).isEmpty else { return }
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
            guard !string(result["recording_id"]).isEmpty else { throw RuntimeFailure("UPLOAD", "Invalid upload response. Retry safely with the same recording ID.") }
            var draft = try store.draft(id)
            draft["recording_id"] = result["recording_id"]; draft["job_id"] = string(result["job_id"])
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
        guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, owner == store.scope else { return }
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

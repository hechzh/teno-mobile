import Foundation

/// All authenticated UI, live and upload requests share one refresh task.
@MainActor final class SessionTransport {
    let store: NativeStore
    private var refreshTask: Task<Void, Error>?
    private let session: URLSession
    init(_ store: NativeStore, session: URLSession = .shared) { self.store = store; self.session = session }
    static func validateBase(_ value: String) throws -> String {
        guard let url = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              url.scheme == "https" || url.scheme == "http" && host == "127.0.0.1" else {
            throw RuntimeFailure("SERVER_ADDRESS", "Use an HTTPS server address without a path or account details.")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    func makeRequest(_ method: String, _ path: String, token: String? = nil) throws -> URLRequest {
        guard path.hasPrefix("/api/v1/"), let parsed = URLComponents(string: path),
              parsed.host == nil, parsed.scheme == nil, !parsed.path.split(separator: "/").contains(".."),
              let url = URL(string: store.base + path) else {
            throw RuntimeFailure("INVALID_ROUTE", "Unsupported API request.")
        }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(store.base, forHTTPHeaderField: "Origin")
        let credential = try token ?? store.token("access_token")
        if !credential.isEmpty { request.setValue("Bearer " + credential, forHTTPHeaderField: "Authorization") }
        return request
    }
    func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw RuntimeFailure("NETWORK", "No HTTP response was received.") }
        if (200..<300).contains(http.statusCode) { return }
        let body = (try? jsonObject(data)) ?? [:]
        throw RuntimeFailure(string(body["code"]).isEmpty ? "HTTP_" + String(http.statusCode) : string(body["code"]),
            http.statusCode == 401 && string(body["code"]) != "INVALID_CREDENTIALS" ? "Your session expired. Sign in again." :
                string(body["message"]).isEmpty ? "Request failed (" + String(http.statusCode) + ")." : string(body["message"]))
    }
    func refresh(after oldToken: String) async throws {
        if try store.token("access_token") != oldToken { return }
        if let existing = refreshTask { try await existing.value; return }
        let owner = store.scope
        let task = Task { @MainActor in
            let refreshToken = try self.store.token("refresh_token")
            guard !refreshToken.isEmpty else { throw RuntimeFailure("UNAUTHORIZED", "Sign in again to resume cloud processing.") }
            var request = try self.makeRequest("POST", "/api/v1/auth/refresh", token: "")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try jsonData(["refresh_token": refreshToken])
            let (bytes, response) = try await self.session.data(for: request)
            try self.validate(response, data: bytes)
            guard owner == self.store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
            try self.store.saveTokens(jsonObject(bytes))
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }
    func data(_ method: String, _ path: String, body: JSONObject? = nil, authenticated: Bool = true) async throws -> Data {
        let owner = store.scope
        for attempt in 0..<2 {
            let old = authenticated ? try store.token("access_token") : ""
            var request = try makeRequest(method, path, token: old)
            if let body { request.httpBody = try jsonData(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            let (bytes, response) = try await session.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 401 && authenticated && attempt == 0 {
                try await refresh(after: old); continue
            }
            try validate(response, data: bytes)
            guard !authenticated || owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed. Reload this page.") }
            return bytes
        }
        throw RuntimeFailure("UNAUTHORIZED", "Sign in again.")
    }
    func json(_ method: String, _ path: String, body: JSONObject? = nil, authenticated: Bool = true) async throws -> JSONObject {
        try jsonObject(await data(method, path, body: body, authenticated: authenticated))
    }
    func login(server: String, username: String, password: String) async throws {
        store.base = try Self.validateBase(server)
        do {
            let tokens: JSONObject
            do { tokens = try await json("POST", "/api/v1/auth/login", body: ["username": username, "password": password], authenticated: false) }
            catch let error as RuntimeFailure where ["INVALID_CREDENTIALS", "HTTP_401", "UNAUTHORIZED"].contains(error.code) {
                throw RuntimeFailure("INVALID_CREDENTIALS", "Invalid username or password. Check your Teno account and try again.")
            }
            try store.saveTokens(tokens)
            let me = try await json("GET", "/api/v1/me")
            store.identity(username, string(me["id"]))
            // Interface language is device-local. A fresh iOS installation must not
            // overwrite this account's existing transcription/summary preferences.
            store.preferences.set(true, forKey: "native_preferences." + store.scope)
        } catch { try? store.logout(); throw error }
    }
    /// Small user-initiated voice/calendar requests; large imports use file-backed background uploads.
    func uploadSmall(_ path: String, file: URL, filename: String) async throws -> JSONObject {
        let size = try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 2_000_000 else { throw RuntimeFailure("UPLOAD_LIMIT", "This file exceeds the upload limit.") }
        let owner = store.scope, boundary = "Teno-" + UUID().uuidString
        let safe = filename.replacingOccurrences(of:"\"",with:"_").replacingOccurrences(of:"\r",with:"_").replacingOccurrences(of:"\n",with:"_")
        var payload = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safe)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
        payload.append(try Data(contentsOf:file)); payload.append(Data("\r\n--\(boundary)--\r\n".utf8))
        for attempt in 0..<2 {
            let old = try store.token("access_token"); var request = try makeRequest("POST",path,token:old)
            request.setValue("multipart/form-data; boundary=" + boundary,forHTTPHeaderField:"Content-Type"); request.httpBody = payload
            let (bytes,response) = try await session.data(for:request)
            if (response as? HTTPURLResponse)?.statusCode == 401 && attempt == 0 { try await refresh(after:old); continue }
            try validate(response,data:bytes)
            guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
            return try jsonObject(bytes)
        }
        throw RuntimeFailure("UNAUTHORIZED", "Sign in again.")
    }
    func download(_ path: String, destination: URL) async throws {
        let owner = store.scope
        for attempt in 0..<2 {
            let old = try store.token("access_token")
            let request = try makeRequest("GET", path, token: old)
            let (temporary, response) = try await session.download(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 401 && attempt == 0 { try await refresh(after: old); continue }
            try validate(response, data: Data())
            guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: temporary, to: destination)
            return
        }
    }
}

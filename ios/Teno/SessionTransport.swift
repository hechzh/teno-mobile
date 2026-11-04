import Foundation

/// All authenticated UI, live and upload requests share one refresh task.
@MainActor final class SessionTransport {
    let store: NativeStore
    private var refreshTask: Task<Void, Error>?
    init(_ store: NativeStore) { self.store = store }
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
            http.statusCode == 401 ? "Your session expired. Sign in again." :
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
            let (bytes, response) = try await URLSession.shared.data(for: request)
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
            let (bytes, response) = try await URLSession.shared.data(for: request)
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
            let tokens = try await json("POST", "/api/v1/auth/login", body: ["username": username, "password": password], authenticated: false)
            try store.saveTokens(tokens)
            let me = try await json("GET", "/api/v1/me")
            store.identity(username, string(me["id"]))
            let marker = "native_preferences." + store.scope
            if !store.preferences.bool(forKey: marker) {
                let settings = me["settings"] as? JSONObject ?? [:]
                _ = try await json("PATCH", "/api/v1/me", body: ["language": "auto", "summary_language": "en-US",
                    "timezone": settings["timezone"] ?? TimeZone.current.identifier])
                store.preferences.set(true, forKey: marker)
            }
        } catch { try? store.logout(); throw error }
    }
    func download(_ path: String, destination: URL) async throws {
        let owner = store.scope
        for attempt in 0..<2 {
            let old = try store.token("access_token")
            let request = try makeRequest("GET", path, token: old)
            let (temporary, response) = try await URLSession.shared.download(for: request)
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

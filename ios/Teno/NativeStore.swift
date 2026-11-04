import Foundation
import CryptoKit
import Security

typealias JSONObject = [String: Any]
func jsonObject(_ data: Data) throws -> JSONObject {
    guard let value = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
        throw RuntimeFailure("INVALID_RESPONSE", "The server returned an invalid response.")
    }
    return value
}
func jsonData(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
func jsonString(_ value: Any) -> String { (try? String(data: jsonData(value), encoding: .utf8)) ?? "{}" }
func string(_ value: Any?) -> String { value as? String ?? "" }
struct RuntimeFailure: Error, LocalizedError {
    let code: String
    let message: String
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
    var errorDescription: String? { message }
}

/// Keychain items stay on this device; no cloud keychain access group is required.
final class KeyVault {
    private let service = "com.teno.runtime"
    func data(_ name: String) throws -> Data? {
        let query: JSONObject = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: name,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw RuntimeFailure("KEYCHAIN_LOCKED", "Unlock your phone to access Teno credentials.") }
        return result as? Data
    }
    func set(_ name: String, _ value: Data?) throws {
        let query: JSONObject = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: name]
        guard let value else { SecItemDelete(query as CFDictionary); return }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw RuntimeFailure("KEYCHAIN_WRITE", "Credentials could not be saved. No device binding was sent.")
            }
        } else if status != errSecSuccess {
            throw RuntimeFailure("KEYCHAIN_WRITE", "Credentials could not be saved.")
        }
    }
}

@MainActor final class NativeStore {
    let preferences = UserDefaults.standard
    let vault = KeyVault()
    let root: URL
    init() throws {
        root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Teno", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var noBackup = URLResourceValues(); noBackup.isExcludedFromBackup = true
        var location = root; try location.setResourceValues(noBackup)
    }
    var base: String {
        get { preferences.string(forKey: "server") ?? "https://54-214-180-183.sslip.io" }
        set { preferences.set(newValue, forKey: "server") }
    }
    var scope: String { preferences.string(forKey: "scope") ?? "" }
    var username: String { preferences.string(forKey: "username") ?? "" }
    var cloudUpload: Bool { preferences.bool(forKey: "auto_upload." + scope) }
    var wifiOnly: Bool { preferences.bool(forKey: "wifi_upload." + scope) }
    var livePreview: Bool { preferences.object(forKey: "live_default") as? Bool ?? true }
    var optionsSet: Bool { preferences.bool(forKey: "recording_options." + scope) }
    func configure(cloud: Bool, wifi: Bool, live: Bool) {
        preferences.set(cloud, forKey: "auto_upload." + scope)
        preferences.set(wifi, forKey: "wifi_upload." + scope)
        preferences.set(live, forKey: "live_default")
        preferences.set(true, forKey: "recording_options." + scope)
    }
    func token(_ name: String) throws -> String {
        guard let bytes = try vault.data("session") else { return "" }
        return string(try jsonObject(bytes)[name])
    }
    func saveTokens(_ value: JSONObject) throws { try vault.set("session", jsonData(value)) }
    func identity(_ username: String, _ id: String) {
        let digest = Data(SHA256.hash(data: Data((base + id).utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        preferences.set(username, forKey: "username"); preferences.set(digest, forKey: "scope")
    }
    func logout() throws {
        try vault.set("session", nil)
        preferences.removeObject(forKey: "username"); preferences.removeObject(forKey: "scope")
    }
    func deviceKey(_ identifier: String) throws -> String {
        guard let value = try vault.data("device." + identifier) else { return "" }
        return String(data: value, encoding: .utf8) ?? ""
    }
    func saveDeviceKey(_ identifier: String, _ key: String) throws {
        guard key.range(of: "^[A-Za-z0-9]{16}$", options: .regularExpression) != nil else {
            throw RuntimeFailure("DEVICE_KEY", "Enter a 16-character key using letters and numbers.")
        }
        try vault.set("device." + identifier, Data(key.utf8))
    }
    func directory(_ owner: String? = nil) throws -> URL {
        let account = owner ?? scope
        guard !account.isEmpty, account.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            throw RuntimeFailure("SIGN_IN_REQUIRED", "Sign in to the recording's account.")
        }
        let folder = root.appendingPathComponent("drafts/" + account, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    func draft(_ id: String, owner: String? = nil) throws -> JSONObject {
        guard id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else {
            throw RuntimeFailure("INVALID_RECORDING", "Invalid local recording.")
        }
        return try jsonObject(Data(contentsOf: directory(owner).appendingPathComponent(id + ".json")))
    }
    func save(_ draft: JSONObject, owner: String? = nil) throws {
        let account = owner ?? scope
        guard string(draft["scope"]) == account else { throw RuntimeFailure("ACCOUNT_CHANGED", "The recording belongs to another account.") }
        let id = string(draft["id"])
        guard id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { throw RuntimeFailure("INVALID_RECORDING", "Invalid recording identifier.") }
        try jsonData(draft).write(to: directory(account).appendingPathComponent(id + ".json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func drafts() -> [JSONObject] {
        guard !scope.isEmpty, let folder = try? directory(),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap { try? jsonObject(Data(contentsOf: $0)) }
            .sorted { string($0["created_at"]) > string($1["created_at"]) }
    }
    func newDraft(_ title: String, ext: String, id: String = UUID().uuidString.lowercased()) throws -> JSONObject {
        return ["id": id, "title": title, "path": try directory().appendingPathComponent(id + "." + ext).path,
            "language": "auto", "scope": scope, "created_at": ISO8601DateFormatter().string(from: Date()), "status": "local"]
    }
    func notes(_ key: String) -> String { preferences.string(forKey: "notes." + scope + "." + key) ?? "" }
    func saveNotes(_ key: String, _ text: String) { preferences.set(text, forKey: "notes." + scope + "." + key) }
    func state() -> SessionState {
        SessionState(signedIn: !scope.isEmpty && !((try? token("access_token")) ?? "").isEmpty,
            username: username, scope: scope, server: base, cloudUpload: cloudUpload,
            wifiOnly: wifiOnly, livePreview: livePreview, optionsSet: optionsSet)
    }
}

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
    private let service: String
    init(service: String = "com.teno.runtime") { self.service = service }
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
    let preferences: UserDefaults
    let vault: KeyVault
    let root: URL
    init(preferences: UserDefaults = .standard, root: URL? = nil, vault: KeyVault = KeyVault()) throws {
        self.preferences = preferences; self.vault = vault
        self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Teno", isDirectory: true)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        var noBackup = URLResourceValues(); noBackup.isExcludedFromBackup = true
        var location = self.root; try location.setResourceValues(noBackup)
        if preferences.object(forKey:"recorder.legacy_owner") == nil { preferences.set(scope,forKey:"recorder.legacy_owner") }
    }
    var base: String {
        get { preferences.string(forKey: "server") ?? "https://54-214-180-183.sslip.io" }
        set { preferences.set(newValue, forKey: "server") }
    }
    var scope: String { preferences.string(forKey: "scope") ?? "" }
    var outputLanguage: String {
        let chosen = preferences.string(forKey:"interface_locale") ?? "system"
        return (chosen == "zh" || chosen == "system" && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")) ? "zh-CN" : "en-US"
    }
    func generationOptions(_ draft: inout JSONObject, from args: JSONObject) throws {
        guard let language = args["output_language"] as? String else { return }
        let origin = args["output_language_origin"] as? String ?? "interface"
        guard ["zh-CN","en-US"].contains(language), ["interface","override"].contains(origin) else { throw RuntimeFailure("LANGUAGE","Choose Chinese or English.") }
        draft["output_language"] = language; draft["output_language_origin"] = origin
    }
    func freezeGeneration(_ draft: inout JSONObject) {
        if draft["generation_frozen"] as? Bool != true || string(draft["output_language"]).isEmpty {
            if string(draft["template_id"]).isEmpty || string(draft["template_id"]) == "@default" {
                let settings = preferences.data(forKey:"personal." + scope + ".settings").flatMap { try? jsonObject($0) } ?? [:]
                draft["template_id"] = settings["default_template_id"] as? String ?? "teno:brief"; draft["template_origin"] = "account"
            } else if draft["template_origin"] == nil { draft["template_origin"] = "selection" }
            if string(draft["output_language"]).isEmpty {
                draft["output_language"] = outputLanguage; draft["output_language_origin"] = "interface"
            }
            draft["generation_frozen"] = true; draft["template_frozen"] = true
        }
    }
    func recorderOptions(_ id: String) -> JSONObject {
        var value = preferences.data(forKey:"note.options." + scope + "." + id).flatMap { try? jsonObject($0) } ?? [:]
        value["template_id"] = preferences.string(forKey:"note.template." + scope + "." + id) ?? "@default"
        return value
    }
    func recorderOptions(_ id: String, _ args: JSONObject) throws {
        var value = recorderOptions(id); try generationOptions(&value,from:args)
        preferences.set(try jsonData(value),forKey:"note.options." + scope + "." + id)
        preferences.set(string(args["template_id"]),forKey:"note.template." + scope + "." + id)
    }
    var username: String { preferences.string(forKey: "username") ?? "" }
    var cloudUpload: Bool { preferences.object(forKey: "auto_upload." + scope) as? Bool ?? true }
    var wifiOnly: Bool { preferences.bool(forKey: "wifi_upload." + scope) }
    var livePreview: Bool { false } // Keep the bridge field for compatibility.
    var optionsSet: Bool { preferences.bool(forKey: "recording_options." + scope) }
    func configure(cloud: Bool, wifi: Bool, live: Bool) {
        preferences.set(cloud, forKey: "auto_upload." + scope)
        preferences.set(wifi, forKey: "wifi_upload." + scope)
        preferences.set(false, forKey: "live_default")
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
        guard !scope.isEmpty else { return "" }
        let scoped = try vault.data("device." + scope + "." + identifier)
        let legacy = scope == preferences.string(forKey:"recorder.legacy_owner") && !preferences.bool(forKey:"recorder.revoked." + scope + "." + identifier)
        guard let value = try scoped ?? (legacy ? vault.data("device." + identifier) : nil) else { return "" }
        return String(data: value, encoding: .utf8) ?? ""
    }
    func denyOfflineRecorder(_ identifier: String) {
        preferences.set(true,forKey:"recorder.deny_offline." + scope + "." + identifier)
    }
    func permitsOfflineRecorder(_ identifier: String) -> Bool {
        !preferences.bool(forKey:"recorder.deny_offline." + scope + "." + identifier)
    }
    func directKeyVerified(_ identifier: String) -> Bool {
        preferences.bool(forKey:"recorder.direct_verified." + scope + "." + identifier)
    }
    func saveDeviceKey(_ identifier: String, _ key: String, verifiedDirect: Bool = false) throws {
        guard key.range(of: "^[A-Za-z0-9]{16}$", options: .regularExpression) != nil else {
            throw RuntimeFailure("DEVICE_KEY", "Enter a 16-character key using letters and numbers.")
        }
        guard !scope.isEmpty else { throw RuntimeFailure("SIGN_IN","Sign in to connect your recorder.") }
        let flag = "recorder.direct_verified." + scope + "." + identifier
        preferences.removeObject(forKey:flag)
        try vault.set("device." + scope + "." + identifier, Data(key.utf8))
        if verifiedDirect {
            preferences.set(true,forKey:flag)
            preferences.removeObject(forKey:"recorder.deny_offline." + scope + "." + identifier)
        }
    }
    var recorderId: String { preferences.string(forKey:"recorder.id." + scope) ?? (scope == preferences.string(forKey:"recorder.legacy_owner") ? preferences.string(forKey:"recorder.id") ?? "" : "") }
    var recorderName: String { preferences.string(forKey:"recorder.name." + scope) ?? "Recorder" }
    var selectedRecorder: String { preferences.string(forKey:"recorder.selected." + scope) ?? "" }
    func selectRecorder(_ hardware: String) { preferences.set(hardware,forKey:"recorder.selected." + scope); preferences.set("",forKey:"recorder.id." + scope) }
    func rememberRecorder(_ id: String, _ name: String) { preferences.set(id,forKey:"recorder.id." + scope); preferences.set(name,forKey:"recorder.name." + scope) }
    func recorderIdentity(_ id: String) -> JSONObject { preferences.data(forKey:"recorder.identity." + scope + "." + id).flatMap { try? jsonObject($0) } ?? [:] }
    func recorderIdentity(_ id: String, _ value: JSONObject) throws { preferences.set(try jsonData(value),forKey:"recorder.identity." + scope + "." + id) }
    func forgetRecorder(_ id: String) throws {
        preferences.removeObject(forKey:"recorder.direct_verified." + scope + "." + id)
        try vault.set("device." + scope + "." + id,nil); try recorderIdentity(id,[:])
        preferences.set(true,forKey:"recorder.revoked." + scope + "." + id)
        preferences.set("",forKey:"recorder.id." + scope); preferences.removeObject(forKey:"recorder.selected." + scope)
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
        return files.filter { $0.pathExtension == "json" }.compactMap { file -> JSONObject? in
            guard var value = try? jsonObject(Data(contentsOf:file)) else { return nil }
            if string(value["recording_id"]).isEmpty && string(value["file_id"]).isEmpty && string(value["output_language"]).isEmpty && string(value["status"]) != "recording" {
                value["output_language"] = outputLanguage; value["output_language_origin"] = "interface"; try? save(value)
            }; return value
        }
            .sorted { string($0["created_at"]) > string($1["created_at"]) }
    }
    func newDraft(_ title: String, ext: String, id: String = UUID().uuidString.lowercased()) throws -> JSONObject {
        return ["id": id, "title": title, "path": try directory().appendingPathComponent(id + "." + ext).path,
            "language": "auto", "scope": scope, "created_at": ISO8601DateFormatter().string(from: Date()), "status": "local"]
    }
    func notes(_ key: String) -> String { preferences.string(forKey: "notes." + scope + "." + key) ?? "" }
    var workspaceFolder: String { preferences.string(forKey: "workspace.folder." + scope) ?? "" }
    func checkedWorkspaceFolder(_ folder: String) throws -> String {
        guard folder.isEmpty || UUID(uuidString: folder) != nil else {
            throw RuntimeFailure("WORKSPACE", "Invalid workspace.")
        }
        return folder
    }
    func selectWorkspace(owner: String, folder: String) throws {
        guard !owner.isEmpty, owner == scope else {
            throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.")
        }
        preferences.set(try checkedWorkspaceFolder(folder), forKey: "workspace.folder." + owner)
    }
    private func recorderStartKey(_ device: String, _ name: String) -> String {
        "workspace.recorder." + scope + "." + device + "|" + (name as NSString).deletingPathExtension
    }
    func rememberRecorderStart(_ device: String, _ name: String, folder: String, recordedAt: Date?) {
        var capture = ["folder_id": folder]
        if let recordedAt { capture["recorded_at"] = ISO8601DateFormatter().string(from: recordedAt) }
        preferences.set(capture, forKey: recorderStartKey(device,name))
    }
    func recorderStart(_ device: String, _ name: String) -> [String:String] {
        (preferences.dictionary(forKey: recorderStartKey(device,name)) as? [String:String]) ?? [:]
    }
    func clearRecorderStart(_ device: String, _ name: String) {
        preferences.removeObject(forKey: recorderStartKey(device,name))
    }
    func saveNotes(_ key: String, _ text: String) { preferences.set(text, forKey: "notes." + scope + "." + key) }
    func state() -> SessionState {
        SessionState(signedIn: !scope.isEmpty && !((try? token("access_token")) ?? "").isEmpty,
            username: username, scope: scope, server: base, cloudUpload: cloudUpload,
            wifiOnly: wifiOnly, livePreview: livePreview, optionsSet: optionsSet)
    }
}

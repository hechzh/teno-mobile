import Foundation
import CryptoKit

@MainActor protocol RecorderOwnershipPort: AnyObject {
    func ownershipKey(_ key: String)
    func ownershipReconnect()
    func ownershipInventory()
    func ownershipUnbind()
    func ownershipReady()
    func ownershipChanged()
    func ownershipClose(_ message: String)
    func ownershipSeek()
    func ownershipReadIdentity()
}

/// The journal contains authorization secrets and lives only in this account's Keychain item.
@MainActor final class RecorderOwnership {
    let store: NativeStore, api: SessionTransport
    weak var port: RecorderOwnershipPort?
    private var operation: JSONObject = [:], recorder: JSONObject = [:]
    private var owner = "", identifier = "", name = "", auth = "", before = ""
    private var generation = 0
    private var rejectedClaimHardware = "", rejectedClaimOwner = ""
    private var pairingKey = "", pairingExpected = "", operationIdentityToVerify = ""
    private(set) var hardware = "", stage = "", state = "disconnected", message = ""
    private(set) var running = false, requesting = false
    init(store: NativeStore, api: SessionTransport) { self.store = store; self.api = api; owner = store.scope
        if let saved = try? store.vault.data("recorder.operation." + owner), let value = try? jsonObject(saved) {
            operation = value; recorder = value["recorder"] as? JSONObject ?? [:]; state = "recovery_required"; message = "Continue the pending recorder operation."
        }
    }
    var blocked: Bool { running || requesting || !["owned","offline_owned"].contains(state) }
    var view: JSONObject { ["state":state,"message":message,"hardware_id":hardware,"recorder":recorder,
        "operation_id":string(operation["id"]),"stage":stage,"busy":running || requesting,"claim_required":state == "claim_required"] }
    static func canonical(_ value: String) throws -> String {
        let value = value.replacingOccurrences(of:":",with:"").replacingOccurrences(of:"-",with:"").uppercased()
        guard value.range(of:"^[0-9A-F]{12}$",options:.regularExpression) != nil, !["000000000000","FFFFFFFFFFFF"].contains(value) else {
            throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.")
        }; return value
    }
    static func inventoryHash(_ entries: [String]) -> String { SHA256.hash(data:Data(entries.sorted().joined(separator:"\n").utf8)).map { String(format:"%02x",$0) }.joined() }
    private var journal: String { "recorder.operation." + owner }
    private func persist() throws { operation["local_stage"] = stage; operation["files_before"] = before; try store.vault.set(journal,jsonData(operation)) }
    func cancel() { connectionAttempt(); running = false; state = "disconnected" }
    func connectionAttempt() { generation += 1; requesting = false; auth = ""; pairingKey = ""; pairingExpected = ""; operationIdentityToVerify = "" }
    var pairing: Bool { !pairingKey.isEmpty || auth == "pairing" }
    private func update(_ state: String, _ message: String) { self.state = state; self.message = message; port?.ownershipChanged() }
    func fail(_ text: String) { connectionAttempt(); running = false; update("recovery_required",text); port?.ownershipClose(text) }
    private func request(_ path: String, _ body: JSONObject, done: @escaping (JSONObject) throws -> Void, offline: (() throws -> Void)? = nil) {
        generation += 1; let ticket = generation, scope = store.scope
        requesting = true; port?.ownershipChanged()
        Task {
            do {
                let result = try await api.json("POST",path,body:body)
                guard ticket == generation, scope == store.scope, store.state().signedIn else { return }
                requesting = false; try done(result)
            } catch {
                guard ticket == generation, scope == store.scope, store.state().signedIn else { return }
                requesting = false
                do { if error is URLError, let offline { try offline() } else { throw error } }
                catch { fail(error.localizedDescription) }
            }
        }
    }
    /// The caller binds consent to the live, GATT-verified peripheral. Never use its BLE address as its protocol identity.
    func pairBeforeIdentity(id: String, name: String, selectedHardware: String = "") throws {
        guard !requesting else { throw RuntimeFailure("RECORDER_BUSY","Finish the current device operation first.") }
        identifier = id; self.name = name; owner = store.scope
        let cached = string(store.recorderIdentity(id)["hardware_id"])
        guard selectedHardware.isEmpty || cached.isEmpty || selectedHardware == cached else {
            throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.")
        }
        let expected = cached.isEmpty ? selectedHardware : cached
        if running {
            let target = string(recorder["hardware_id"])
            guard !target.isEmpty, expected == target || string(operation["verified_peripheral"]) == id else {
                throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.")
            }
            operationIdentityToVerify = target; try authenticate(); return
        }
        guard try store.vault.data(journal) == nil else {
            throw RuntimeFailure("RECORDER_BUSY","Continue the pending recorder operation.")
        }
        hardware = ""; auth = "pairing"; pairingKey = ""; pairingExpected = expected
        update("checking","Checking recorder ownership")
        if pairingExpected.isEmpty {
            request("/api/v1/recorders/pairing-key",["confirm":true],done:{ [self] in try sendPairingKey($0) })
        } else {
            request("/api/v1/recorders/resolve",["hardware_id":pairingExpected],done:{ [self] result in
                let known = result["recorder"] as? JSONObject ?? [:]
                guard string(result["state"]) == "owned", string(known["hardware_id"]) == pairingExpected else {
                    throw RuntimeFailure("RECORDER_OWNER","Ask the owner to transfer this recorder.")
                }
                request("/api/v1/recorders/" + string(known["id"]) + "/restore",[:],done:{ [self] in try sendPairingKey($0) })
            })
        }
    }
    private func sendPairingKey(_ result: JSONObject) throws {
        let key = string(result["device_key"])
        guard key.range(of:"^[A-Za-z0-9]{16}$",options:.regularExpression) != nil else {
            throw RuntimeFailure("RECORDER_KEY","Recorder authorization is unavailable.")
        }
        pairingKey = key; port?.ownershipKey(key)
    }
    func identity(_ value: String, id: String, name: String) throws {
        if (pairing || !operationIdentityToVerify.isEmpty) && (owner != store.scope || identifier != id) {
            throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.")
        }
        hardware = try Self.canonical(value); identifier = id; self.name = name; owner = store.scope
        if !operationIdentityToVerify.isEmpty {
            guard hardware == operationIdentityToVerify else { throw RuntimeFailure("RECORDER_IDENTITY","The recorder returned a different hardware ID. No recordings were accessed.") }
            operationIdentityToVerify = ""; try accepted(); return
        }
        if pairing && !pairingExpected.isEmpty && hardware != pairingExpected {
            throw RuntimeFailure("RECORDER_IDENTITY","The recorder returned a different hardware ID. No recordings were accessed.")
        }
        let target = running ? string((operation["recorder"] as? JSONObject)?["hardware_id"]) : (pairing ? "" : store.selectedRecorder)
        if !target.isEmpty, target != hardware { port?.ownershipSeek(); return }
        if running { operation["verified_peripheral"] = id; try persist(); try authenticate(); return }
        update("checking","Checking recorder ownership")
        request("/api/v1/recorders/resolve",["hardware_id":hardware],done:{ [self] result in
            switch string(result["state"]) {
            case "owned":
                recorder = result["recorder"] as? JSONObject ?? [:]
                if !string(recorder["operation_id"]).isEmpty {
                    operation = ["id":string(recorder["operation_id"])]; update("recovery_required","Continue the pending recorder operation."); port?.ownershipClose(message); return
                }
                request("/api/v1/recorders/" + string(recorder["id"]) + "/restore",[:],done:{ [self] restored in
                    recorder = restored; let key = string(recorder.removeValue(forKey:"device_key"))
                    if pairing && key != pairingKey { throw RuntimeFailure("RECORDER_KEY","Recorder authorization could not be verified.") }
                    try store.saveDeviceKey(identifier,key); try store.recorderIdentity(identifier,recorder)
                    if pairing { pairingKey = ""; pairingExpected = ""; auth = "owned"; try accepted() }
                    else { auth = "owned"; port?.ownershipKey(key) }
                })
            case "claim_required":
                operation = [:]; recorder = [:]; update("claim_required","Confirm this recorder and its existing recordings.")
                if pairing { try claim("",confirmed:true) }
            default: try store.forgetRecorder(identifier); update("transfer_required","Ask the owner to transfer this recorder."); port?.ownershipClose(message)
            }
        },offline:{ [self] in
            let cached = store.recorderIdentity(identifier), key = try store.deviceKey(identifier)
            guard !pairing, string(cached["hardware_id"]) == hardware, !key.isEmpty, try store.vault.data(journal) == nil else {
                throw RuntimeFailure("RECORDER_ONLINE","Connect to the internet to restore recorder authorization.")
            }
            recorder = cached; auth = "offline_owned"; port?.ownershipKey(key)
        })
    }
    func claim(_ original: String, confirmed: Bool) throws {
        guard confirmed, state == "claim_required", !requesting else { throw RuntimeFailure("RECORDER_CONFIRM","Confirm the connected recorder first.") }
        var body: JSONObject = ["client_id":UUID().uuidString,"hardware_id":hardware,"name":name,"confirm_card_recordings":true]
        var key = original
        if key.isEmpty && rejectedClaimHardware == hardware && rejectedClaimOwner == store.scope {
            key = try store.deviceKey(identifier)
        }
        if pairing { body["account_key_only"] = true }
        else if !key.isEmpty { body["original_key"] = key }
        request("/api/v1/recorders/claim",body,done:{ [self] value in operation = value; try start(string(value["id"])) })
    }
    func start(_ id: String) throws {
        guard !requesting else { throw RuntimeFailure("RECORDER_BUSY","Wait for the current recorder request.") }
        owner = store.scope
        request("/api/v1/recorders/operations/" + id + "/start",[:],done:{ [self] value in
            operation = value; recorder = value["recorder"] as? JSONObject ?? [:]
            if string(value["state"]) == "completed" { try store.vault.set(journal,nil); if string(value["kind"]) != "claim", !identifier.isEmpty { try store.forgetRecorder(identifier) }; running = false; update("completed","Recorder operation completed"); return }
            if !identifier.isEmpty && hardware == string(recorder["hardware_id"]) { operation["verified_peripheral"] = identifier }
            let point = value["checkpoint"] as? JSONObject ?? [:]
            before = string(point["files_before"]); stage = string(point["stage"]); running = true; try persist()
            if pairing {
                guard string(value["kind"]) == "claim", string(recorder["hardware_id"]) == hardware,
                      string(value["device_key"]) == pairingKey else { throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.") }
                pairingKey = ""; pairingExpected = ""; auth = "claim"; try complete(""); return
            }
            update("changing","Verifying recorder authorization"); store.selectRecorder(string(recorder["hardware_id"]))
            if hardware == string(recorder["hardware_id"]) { port?.ownershipReconnect() } else { port?.ownershipSeek() }
        })
    }
    private func authenticate() throws {
        if string(operation["kind"]) == "claim" { auth = "claim"; port?.ownershipKey(string(operation["device_key"])); return }
        if stage.isEmpty || stage == "inventory_saved" { auth = "before"; port?.ownershipKey(string(operation["previous_key"])) }
        else if stage == "new_key_accepted" { auth = "reject_old"; port?.ownershipKey(string(operation["previous_key"])) }
        else { auth = "new"; port?.ownershipKey(string(operation["device_key"])) }
    }
    func accepted() throws {
        if !operationIdentityToVerify.isEmpty && auth != "reject_old" { port?.ownershipReadIdentity(); return }
        switch auth {
        case "pairing": port?.ownershipReadIdentity()
        case "owned","offline_owned": update(auth,"Recorder connected"); store.rememberRecorder(identifier,name); port?.ownershipReady()
        case "claim": try complete("")
        case "reject_old": fail("The previous authorization is still accepted. Transfer was not completed.")
        case "before": port?.ownershipInventory()
        case "new":
            if stage == "old_key_rejected" { port?.ownershipInventory() }
            else { try checkpoint("new_key_accepted") { self.port?.ownershipReconnect() } }
        default: break
        }
    }
    func rejected() throws {
        operationIdentityToVerify = ""
        if pairing {
            fail("The recorder rejected this account's key. Use the original account to check its ownership."); return
        }
        if running, auth == "claim" {
            request("/api/v1/recorders/operations/" + string(operation["id"]) + "/claim-rejected",[:],done:{ [self] _ in
                try store.vault.set(journal,nil); operation = [:]; stage = ""; running = false
                rejectedClaimHardware = hardware; rejectedClaimOwner = store.scope
                update("claim_required","Device key was rejected. Use the original key; the recorder was not reset."); port?.ownershipClose(message)
            }); return
        }
        if auth == "reject_old" { try checkpoint("old_key_rejected") { self.port?.ownershipReconnect() }; return }
        if running, auth == "new", stage == "rotation_requested" { stage = "inventory_saved"; try persist(); port?.ownershipReconnect(); return }
        fail("Device key was rejected. Use the original key; the recorder was not reset.")
    }
    private func checkpoint(_ next: String, then: @escaping () throws -> Void) throws {
        request("/api/v1/recorders/operations/" + string(operation["id"]) + "/checkpoint",["stage":next,"files_before":before],done:{ [self] _ in stage = next; try persist(); try then() })
    }
    func inventory(_ entries: [String]) throws {
        let hash = Self.inventoryHash(entries)
        if auth == "before" {
            guard before.isEmpty || before == hash else { throw RuntimeFailure("RECORDER_FILES","Card files changed. Keep the card unchanged while completing the transfer.") }
            before = hash
            try checkpoint("inventory_saved") { try self.checkpoint("rotation_requested") { self.port?.ownershipUnbind() } }
        } else if auth == "new", stage == "old_key_rejected" {
            guard before == hash else { throw RuntimeFailure("RECORDER_FILES","Card file verification failed. Transfer was not completed.") }; try complete(hash)
        }
    }
    private func complete(_ after: String) throws {
        var proof: JSONObject = ["hardware_id":hardware,"new_key_accepted":true]
        if !after.isEmpty { proof["old_key_rejected"] = true; proof["files_before"] = before; proof["files_after"] = after }
        request("/api/v1/recorders/operations/" + string(operation["id"]) + "/complete",proof,done:{ [self] value in
            let claim = string(operation["kind"]) == "claim", key = string(operation["device_key"])
            running = false; recorder = value["recorder"] as? JSONObject ?? [:]; try store.vault.set(journal,nil); operation = [:]; stage = ""
            if claim { rejectedClaimHardware = ""; rejectedClaimOwner = ""; try store.saveDeviceKey(identifier,key); try store.recorderIdentity(identifier,recorder); store.rememberRecorder(identifier,name); update("owned","Recorder connected"); port?.ownershipReady() }
            else { try store.forgetRecorder(identifier); update("completed","Recorder operation completed"); port?.ownershipClose(message) }
        })
    }
}

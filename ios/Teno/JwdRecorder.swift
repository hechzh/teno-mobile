import Foundation
import CoreBluetooth
import CryptoKit
import Security
import AVFoundation
import JwdVtrSDK

/// CoreBluetooth belongs to the host. Vendor callbacks only describe acknowledged hardware state.
@MainActor final class JwdRecorder: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate,
    JWDBleConnectDelegate, JWDAuthDelegate, JWDRecordStateDelegate, JWDBatteryDelegate, JWDFileMgrDelegate, JWDDeviceInfoDelegate, RecorderOwnershipPort {
    static let service = CBUUID(string: "001120A0-2233-4455-6677-889912345678")
    static let characteristics = ["001120A1-2233-4455-6677-889912345678",
        "001120A2-2233-4455-6677-889912345678", "001120A3-2233-4455-6677-889912345678"].map(CBUUID.init(string:))
    private let store: NativeStore, api: SessionTransport
    private let saved: (String) -> Void
    private let sdk = JWDClient.sharedInstance()
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var discovered: [String: CBPeripheral] = [:]
    private var candidates: [String: JSONObject] = [:]
    private var probeOnly = false
    private var automatic = false, autoProbing = false
    private var autoQueue: [String] = [], autoTried = Set<String>()
    private var preferred = ""
    private var explicitlySelectedHardware = ""
    private var restoreCode: (id: String, scope: String, key: String)?
    private var disconnectReason = ""
    private var scanTimer: Task<Void,Never>?
    private var requestGeneration = 0
    private var identityRead: Task<Void,Never>?
    private var deadline: Task<Void,Never>?
    private var commands: [() -> Void] = []
    private var commandTask: Task<Void,Never>?
    private var connectionGeneration = 0
    lazy var ownership: RecorderOwnership = { let value = RecorderOwnership(store:store,api:api); value.port = self; return value }()
    private var ownershipListing = false, ownershipReading = false, ownershipReconnectPending = false, ownershipSeeking = false
    private var ownershipAuthRejected = false
    private var ownershipEntries: [String] = []
    private var listingDirectory = ""
    private(set) var authorized = false, busy = false, receiving = false
    private(set) var identifier = "", name = "", battery = "Not received"
    private(set) var status = "Connect your recorder to get started.", phase = "idle", recordName = "", lastDraft = ""
    private var recordStarted: TimeInterval?, accumulated: Int64 = 0
    private var startFolder = "", syncFolder = ""
    private var waiting = ""
    private var recordStateKnown = false
    private var directories: [String] = [], files: [JSONObject] = [], transferQueue: [JSONObject] = []
    private var transfer: JSONObject?, transferFile: URL?, transferHandle: FileHandle?
    private var transferOwner = ""
    private var transferGeneration = 0
    private var expected: Int64 = 0, received: Int64 = 0
    private var transferCRC: UInt32 = 0
    private var transferHash = SHA256()
    var connected: Bool { peripheral?.state == .connected }
    var active: Bool { ["starting","recording","paused","stopping","saving","interrupted"].contains(phase) }
    var elapsed: Int64 { accumulated + (recordStarted.map { Int64((ProcessInfo.processInfo.systemUptime - $0) * 1000) } ?? 0) }
    var localId: String { recordName.isEmpty ? lastDraft : "jwd:" + identifier + "|" + recordName }
    init(store: NativeStore, api: SessionTransport, saved: @escaping (String) -> Void) {
        self.store = store; self.api = api; self.saved = saved; super.init()
        JWDClient.setDebugMode(false)
        sdk.bleConnectDelegate = self; sdk.authDelegate = self; sdk.recordStateDelegate = self
        sdk.batteryDelegate = self; sdk.fileMgrDelegate = self; sdk.deviceInfoDelegate = self
        identifier = store.recorderId; name = store.recorderName
        if store.preferences.bool(forKey: "recorder.bluetooth_enabled") { initializeBluetooth() }
    }
    private func initializeBluetooth() {
        guard central == nil else { return }
        store.preferences.set(true, forKey: "recorder.bluetooth_enabled")
        central = CBCentralManager(delegate: self, queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.teno.recorder"])
    }
    private func timeout(_ message: String, seconds: UInt64 = 20, disconnect: Bool = false) {
        deadline?.cancel()
        deadline = Task {
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            if ownership.running { ownershipReconnectPending = false; ownership.fail(message); return }
            if waiting == "connection_key" { ownership.connectionAttempt() }
            waiting = ""; busy = false; status = message
            if disconnect { disconnectReason = message }
            if phase == "starting" || phase == "stopping" { phase = "interrupted" }
            if receiving || phase == "saving" { discardTransfer(); phase = "idle" }
            if disconnect, let peripheral { central.cancelPeripheralConnection(peripheral) }
        }
    }
    private func send(_ work: @escaping () -> Void) {
        commands.append(work)
        guard commandTask == nil else { return }
        let generation = connectionGeneration
        commandTask = Task {
            defer { if generation == connectionGeneration { commandTask = nil } }
            while !Task.isCancelled, !commands.isEmpty, connected, generation == connectionGeneration {
                let command = commands.removeFirst(); command()
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
        }
    }
    func command(_ action: DeviceAction, id: String, name: String) async throws {
        if action != .disconnect && action != .stop && action != .cancelTransfer {
            guard store.state().signedIn else { throw RuntimeFailure("SIGN_IN", "Sign in to connect your recorder.") }
        }
        if action == .disconnect {
            restoreCode = nil; ownership.cancel(); ownershipReconnectPending = false; ownershipSeeking = false
            requestGeneration += 1; cancelAutomatic(); central?.stopScan()
            if let device = peripheral {
                central?.cancelPeripheralConnection(device); disconnected(device,error:nil)
            } else {
                deadline?.cancel(); commands.removeAll(); connectionGeneration += 1; commandTask?.cancel(); commandTask = nil; busy = false; authorized = false
            }
            if !active { status = "Disconnected" }; return
        }
        let generation = requestGeneration
        initializeBluetooth()
        let until = Date().addingTimeInterval(30)
        while central.state == .unknown || central.state == .resetting {
            guard generation == requestGeneration else { return }
            guard Date() < until else { throw RuntimeFailure("BLUETOOTH", "Bluetooth is not ready. Allow access and try again.") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard generation == requestGeneration, store.state().signedIn else { return }
        if action == .scan || action == .compatibilityScan {
            guard central.state == .poweredOn else { throw RuntimeFailure("BLUETOOTH", "Turn on Bluetooth and allow Teno access in iOS Settings.") }
            guard !connected && !busy else { throw RuntimeFailure("DEVICE_BUSY", "Finish the current device operation first.") }
            cancelAutomatic(); automatic = true; candidates.removeAll(); discovered.removeAll(); autoTried.removeAll()
            restoreCode = nil; disconnectReason = ""
            preferred = store.recorderId
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
            status = "Searching for your JWD recorder"
            scanTimer = Task { try? await Task.sleep(nanoseconds: 15_000_000_000); if !Task.isCancelled { selectAutomatic() } }
            return
        }
        if action == .probe || action == .connect {
            cancelAutomatic()
            guard !connected && !busy else { throw RuntimeFailure("DEVICE_BUSY", "Disconnect the current recorder first.") }
            let selected = id.isEmpty ? identifier : id
            var found = discovered[selected]
            if found == nil, let uuid = UUID(uuidString: selected) { found = central.retrievePeripherals(withIdentifiers: [uuid]).first }
            guard let device = found else { throw RuntimeFailure("DEVICE_NOT_FOUND", "Scan for your recorder again.") }
            if action == .connect, !id.isEmpty, candidates[id]?["gatt_status"] as? String == "verified", !ownership.running,
               !store.selectedRecorder.isEmpty && explicitlySelectedHardware.isEmpty { store.selectRecorder("") }
            disconnectReason = ""
            ownership.connectionAttempt(); central.stopScan(); peripheral = device; identifier = selected; self.name = name.isEmpty ? device.name ?? "Recorder" : name
            probeOnly = action == .probe; busy = true; authorized = false; status = "Checking recorder service"
            central.connect(device); timeout("Connection timed out. Check your recorder and try again.", disconnect: true); return
        }
        guard authorized, !ownership.blocked else { throw RuntimeFailure("DEVICE_DISCONNECTED", "Connect your recorder first.") }
        if action == .cancelTransfer { sdk.cancelImport(); discardTransfer(); phase = "idle"; busy = false; status = "Transfer paused. The original stays on your recorder."; return }
        guard !busy else { throw RuntimeFailure("DEVICE_BUSY", "Wait for the recorder to respond.") }
        switch action {
        case .refresh:
            send { self.sdk.getBattery() }
            if phase != "paused" { send { self.sdk.getRecordStatus() } }
        case .start:
            guard recordStateKnown else { throw RuntimeFailure("DEVICE_STATE", "Reconnect and wait for the recorder status before starting.") }
            guard !active else { throw RuntimeFailure("RECORDING_ACTIVE", "Check the existing recording before starting another.") }
            waiting = "start"; busy = true; phase = "starting"; lastDraft = ""; recordName = ""
            startFolder = store.workspaceFolder
            status = "Waiting for the recorder to start"; send { self.sdk.startRecord() }
            timeout("Start was not confirmed. Check the recorder before trying again.")
        case .pause:
            guard phase == "recording" else { return }
            busy = true; waiting = "pause"; send { self.sdk.pauseRecord() }; timeout("Pause was not confirmed. Check the recorder.")
        case .resume:
            guard phase == "paused" else { return }
            busy = true; waiting = "resume"; send { self.sdk.resumeRecord() }; timeout("Resume was not confirmed. Check the recorder.")
        case .stop:
            guard active else { return }
            busy = true; waiting = "stop"; phase = "stopping"; status = "Waiting for the recorder to stop"
            send { self.sdk.stopRecord() }; timeout("Stop was not confirmed. The recorder may still be recording.")
        case .sync:
            guard recordStateKnown, !active else { throw RuntimeFailure("SYNC", "Wait for the recorder to stop before syncing.") }
            beginSync(folder:store.workspaceFolder)
        default: break
        }
    }
    private func cancelAutomatic() {
        automatic = false; autoProbing = false
        autoQueue.removeAll(); scanTimer?.cancel()
    }
    func cancelAccountConnection() {
        ownership.cancel(); ownershipReconnectPending = false; ownershipSeeking = false
        requestGeneration += 1; connectionGeneration += 1
        cancelAutomatic(); central?.stopScan(); deadline?.cancel(); identityRead?.cancel()
        commands.removeAll(); commandTask?.cancel(); commandTask = nil
        if let device = peripheral { central?.cancelPeripheralConnection(device) }
        peripheral = nil; authorized = false; busy = false; waiting = ""
        discovered.removeAll(); candidates.removeAll(); disconnectReason = ""; explicitlySelectedHardware = ""; restoreCode = nil
        status = "Sign in to connect your recorder."
    }
    private func selectAutomatic() {
        guard store.state().signedIn, automatic, !autoProbing, !busy else { return }
        central.stopScan(); scanTimer?.cancel()
        autoQueue = Self.connectionOrder(Array(candidates.values), previous:preferred)
        if autoQueue.isEmpty, !preferred.isEmpty, let id = UUID(uuidString: preferred),
           let device = central.retrievePeripherals(withIdentifiers: [id]).first {
            discovered[preferred] = device; autoQueue = [preferred]
        }
        nextAutomaticProbe()
    }
    private func nextAutomaticProbe() {
        guard store.state().signedIn, automatic else { return }
        while !autoQueue.isEmpty {
            let id = autoQueue.removeFirst()
            guard autoTried.insert(id).inserted, let device = discovered[id] else { continue }
            disconnectReason = ""
            ownership.connectionAttempt(); autoProbing = true; probeOnly = true; busy = true; authorized = false
            peripheral = device; identifier = id
            let advertisedName = string(candidates[id]?["name"])
            name = advertisedName.isEmpty ? device.name ?? "JWD recorder" : advertisedName
            status = "Verifying recorder protocol"
            central.connect(device)
            timeout("Connection timed out. Wake your recorder and try again.", disconnect: true)
            return
        }
        automatic = false; busy = false
        if !disconnectReason.isEmpty { status = disconnectReason }
        else if candidates.isEmpty { status = "No JWD recorder found. Wake your recorder and try again." }
        else { status = "Nearby devices found. Check the recorder service." }
    }
    static func candidateName(_ value: String) -> Bool {
        let name = value.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ["VTR","PKT","N10","HV0","HQ","H10","H11","KIOLO","DEX_"].contains { name.hasPrefix($0) }
    }
    static func connectionOrder(_ values: [JSONObject], previous: String) -> [String] {
        let eligible = values.filter { row in
            string(row["gatt_status"]) != "unsupported" &&
                (string(row["address"]) == previous || row["jwd"] as? Bool == true || row["name_match"] as? Bool == true)
        }
        return eligible.sorted {
            if string($0["address"]) == previous { return string($1["address"]) != previous }
            if string($1["address"]) == previous { return false }
            return ($0["rssi"] as? Int ?? -200) > ($1["rssi"] as? Int ?? -200)
        }.map { string($0["address"]) }
    }
    static func newDeviceCode() throws -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8)
        var result = [UInt8]()
        while result.count < 16 {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault,1,&byte) == errSecSuccess else { throw RuntimeFailure("RANDOM", "The device code could not be generated. Try again.") }
            if byte < 248 { result.append(alphabet[Int(byte) % alphabet.count]) }
        }
        return String(bytes: result, encoding: .ascii)!
    }
    func bind(id: String, name: String, key: String, createNew: Bool) async throws {
        guard store.state().signedIn else { throw RuntimeFailure("SIGN_IN", "Sign in to connect your recorder.") }
        guard string(candidates[id]?["gatt_status"]) == "verified" else { throw RuntimeFailure("DEVICE_UNVERIFIED", "Check the recording service first.") }
        guard !createNew else { throw RuntimeFailure("DEVICE_CONFIRM","Confirm the connected recorder first.") }
        guard candidates[id]?["key_rejected"] as? Bool == true, key.range(of:"^[A-Za-z0-9]{16}$",options:.regularExpression) != nil else {
            throw RuntimeFailure("DEVICE_KEY","Enter a 16-character key using letters and numbers.")
        }
        restoreCode = (id,store.scope,key)
        do { try await command(.connect,id:id,name:name) } catch { restoreCode = nil; throw error }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            cancelAutomatic(); central.stopScan(); authorized = false; busy = false
            if active { accumulated = elapsed; phase = "interrupted"; recordStarted = nil }
            status = central.state == .unauthorized ? "Allow Bluetooth access in iOS Settings." : "Turn on Bluetooth to connect your recorder."
        }
    }
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else { return }
        discovered[restored.identifier.uuidString] = restored; peripheral = restored
        identifier = restored.identifier.uuidString; name = restored.name ?? "Recorder"; probeOnly = false
        if restored.state == .connected { verify(restored) }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central.isScanning, store.state().signedIn else { return }
        let id = peripheral.identifier.uuidString
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []) +
            (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
        let serviceMatch = services.contains(Self.service)
        let nameMatch = Self.candidateName(name) || Self.candidateName(peripheral.name ?? "")
        guard (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue != false else { return }
        guard candidates.count < 40 || candidates[id] != nil || serviceMatch || nameMatch || id == preferred else { return }
        discovered[id] = peripheral
        var candidate = candidates[id] ?? ["gatt_status": "unknown"]
        candidate["jwd"] = serviceMatch || candidate["jwd"] as? Bool == true
        candidate["name_match"] = nameMatch || candidate["name_match"] as? Bool == true
        candidate["address"] = id
        if !name.isEmpty || candidate["name"] == nil { candidate["name"] = name }
        candidate["rssi"] = RSSI.intValue == 127 ? -200 : RSSI.intValue
        candidate["has_key"] = !((try? store.deviceKey(id)) ?? "").isEmpty; candidates[id] = candidate
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard store.state().signedIn, self.peripheral === peripheral, busy else { central.cancelPeripheralConnection(peripheral); return }; verify(peripheral)
    }
    private func verify(_ device: CBPeripheral) {
        peripheral = device; busy = true; authorized = false
        device.delegate = self; device.discoverServices([Self.service])
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral === peripheral, busy else { return }
        if error != nil { probeFailed(peripheral); return }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else { unsupported(peripheral); return }
        peripheral.discoverCharacteristics(Self.characteristics, for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard store.state().signedIn else { cancelAccountConnection(); return }
        guard self.peripheral === peripheral, busy else { return }
        if error != nil { probeFailed(peripheral); return }
        guard let chars = service.characteristics, Self.characteristics.allSatisfy({ id in chars.contains { $0.uuid == id } }) else { unsupported(peripheral); return }
        guard chars.contains(where: { $0.uuid == Self.characteristics[1] && (!$0.properties.intersection([.write,.writeWithoutResponse]).isEmpty) }),
              Self.characteristics.filter({ $0 != Self.characteristics[1] }).allSatisfy({ id in chars.contains { $0.uuid == id && $0.properties.contains(.notify) } }) else { unsupported(peripheral); return }
        let id = peripheral.identifier.uuidString
        var verified = candidates[id] ?? ["address":id]
        verified["name"] = name; verified["gatt_status"] = "verified"; verified.removeValue(forKey:"probe_error")
        verified["has_key"] = !((try? store.deviceKey(id)) ?? "").isEmpty; candidates[id] = verified
        if automatic && autoProbing {
            autoProbing = false; probeOnly = false
            status = "Connecting automatically"; sdk.onPeripheralConnected(peripheral)
        } else if probeOnly {
            deadline?.cancel(); busy = false; status = "Recording service verified. Connect using your device key."
            central.cancelPeripheralConnection(peripheral)
        } else { sdk.onPeripheralConnected(peripheral) }
    }
    private func unsupported(_ device: CBPeripheral) {
        candidates[device.identifier.uuidString]?["gatt_status"] = "unsupported"
        deadline?.cancel(); busy = false; status = "This device does not expose the required recording service."
        disconnectReason = status
        central.cancelPeripheralConnection(device)
    }
    private func probeFailed(_ device: CBPeripheral) {
        deadline?.cancel(); busy = false
        disconnectReason = "Could not read recorder services. Try again."
        status = disconnectReason
        candidates[device.identifier.uuidString]?["gatt_status"] = "failed"
        candidates[device.identifier.uuidString]?["probe_error"] = status
        central.cancelPeripheralConnection(device)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard self.peripheral === peripheral else { return }
        disconnectReason = "Connection timed out. Wake your recorder and try again."
        candidates[peripheral.identifier.uuidString]?["gatt_status"] = "failed"
        disconnected(peripheral,error:error)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { disconnected(peripheral,error:error) }
    private func disconnected(_ device: CBPeripheral,error: Error?) {
        guard peripheral?.identifier == device.identifier else { return }
        let continueSelection = automatic && autoProbing
        identityRead?.cancel()
        if ["identity_consent","confirm_identity"].contains(waiting) && disconnectReason.isEmpty {
            disconnectReason = "Recorder disconnected before its hardware ID was verified."
        }
        candidates[identifier]?.removeValue(forKey:"compat_token")
        candidates[identifier]?.removeValue(forKey:"identity_timeout")
        candidates[identifier]?.removeValue(forKey:"operation_compat")
        restoreCode = nil
        if !ownership.running { ownership.connectionAttempt() }
        autoProbing = false; waiting = ""
        device.delegate = nil
        sdk.onPeripheralDisconnected(device,error:error); connectionGeneration += 1; commands.removeAll(); commandTask?.cancel(); commandTask = nil
        deadline?.cancel(); authorized = false; busy = false; recordStateKnown = false; peripheral = nil
        if active { accumulated = elapsed; recordStarted = nil; phase = "interrupted"; status = "Connection interrupted. The recorder may still be recording." }
        else if !disconnectReason.isEmpty { status = disconnectReason }
        else if !probeOnly { status = "Recorder disconnected" }
        discardTransfer()
        ownershipListing = false; ownershipReading = false
        if ownershipSeeking {
            ownershipSeeking = false; startOwnershipScan()
        } else if ownershipReconnectPending {
            ownershipReconnectPending = false; reconnectOwnership(device)
        } else if continueSelection { nextAutomaticProbe() }
        else if (ownership.running || ownership.requesting) && !ownershipAuthRejected { ownership.fail("Recorder disconnected. Continue the pending operation.") }
        else if disconnectReason.isEmpty, candidates[identifier]?["key_rejected"] as? Bool == true { status = "Device key was rejected. Use the original key; the recorder was not reset." }
        ownershipAuthRejected = false
    }
    func onBleConnected(_ peripheral: CBPeripheral) {
        // Some vendor versions report readiness before the second CCCD completes.
        Task {
            for _ in 0..<40 {
                guard store.state().signedIn, self.peripheral === peripheral, connected else { return }
                let notifications = peripheral.services?.flatMap { $0.characteristics ?? [] }.filter { $0.uuid == Self.characteristics[0] || $0.uuid == Self.characteristics[2] } ?? []
                if notifications.count == 2 && notifications.allSatisfy({ $0.isNotifying }) {
                    if !waiting.isEmpty || authorized { return }
                    if ownership.running { readIdentity(afterAuth:false); return }
                    let target = explicitlySelectedHardware
                    let cachedTarget = string(store.recorderIdentity(identifier)["hardware_id"])
                    if !target.isEmpty && !cachedTarget.isEmpty && target != cachedTarget {
                        ownershipSeek(); return
                    }
                    // A stored cloud selection cannot identify an unmapped nearby device.
                    if automatic && !target.isEmpty && cachedTarget.isEmpty {
                        autoProbing = true; disconnectReason = "Select the nearby recorder to connect."; central.cancelPeripheralConnection(peripheral); return
                    }
                    let original = restoreCode
                    restoreCode = nil; waiting = "connection_key"; busy = true
                    candidates[identifier]?["key_rejected"] = false
                    timeout("Connect to the internet to restore recorder authorization.",seconds:20,disconnect:true)
                    do {
                        let key = original?.scope == store.scope && original?.id == identifier ? original?.key ?? "" : ""
                        try ownership.connectWithKey(id:identifier,name:name,original:key,selected:target)
                    } catch { ownership.fail(error.localizedDescription) }
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            status = "Recorder notifications are unavailable."; disconnectReason = status; central.cancelPeripheralConnection(peripheral)
        }
    }
    func onBleDisConnected(_ peripheral: CBPeripheral) {}
    func registerConnected() throws {
        guard store.state().signedIn, authorized, connected, !busy, !active, !receiving, recordStateKnown,
              ownership.state == "authorized", !ownership.running, !ownership.requesting else {
            throw RuntimeFailure("RECORDER_BUSY","Finish recording and syncing before registering this recorder.")
        }
        readIdentity(afterAuth:false,registration:true)
    }
    private func readIdentity(afterAuth: Bool, registration: Bool = false) {
        identityRead?.cancel(); deadline?.cancel()
        let phase = registration ? "registration_identity" : (afterAuth ? "confirm_identity" : "identity")
        let generation = connectionGeneration, scope = store.scope
        waiting = phase; busy = true; status = "Reading recorder identity"
        identityRead = Task {
            // The vendor sample settles for one second after notification setup before its first write.
            for delay: UInt64 in [1,3,4] {
                try? await Task.sleep(nanoseconds:delay * 1_000_000_000)
                guard !Task.isCancelled, generation == connectionGeneration, scope == store.scope,
                      connected, store.state().signedIn, waiting == phase else { return }
                send { if self.waiting == phase { self.sdk.getDeviceMac() } }
            }
            try? await Task.sleep(nanoseconds:4_000_000_000)
            guard !Task.isCancelled, generation == connectionGeneration, scope == store.scope,
                  connected, waiting == phase else { return }
            if registration {
                busy = false; waiting = ""; status = "This recorder did not return a hardware ID. Recording and syncing are still available."; return
            }
            if afterAuth {
                ownership.fail("The recorder did not return its hardware ID after authorization."); return
            }
            waiting = "identity_consent"; busy = false; cancelAutomatic()
            status = "The recorder connected, but did not return its hardware ID. Check the physical recorder before authorizing it."
            candidates[identifier]?["identity_timeout"] = true
            candidates[identifier]?["operation_compat"] = ownership.running
            candidates[identifier]?["compat_token"] = UUID().uuidString
        }
    }
    func selectOwnedRecorder(_ hardware: String) {
        explicitlySelectedHardware = hardware; store.selectRecorder(hardware)
    }
    func confirmPairing(_ args: JSONObject) throws {
        guard store.state().signedIn, connected, !authorized, !busy, waiting == "identity_consent",
              args["confirm"] as? Bool == true, string(args["address"]) == identifier,
              let token = candidates[identifier]?["compat_token"] as? String, token == string(args["compat_token"]),
              candidates[identifier]?["gatt_status"] as? String == "verified" else {
            throw RuntimeFailure("RECORDER_CONFIRM","Confirm the connected recorder first.")
        }
        let selectedHardware = string(args["selected_hardware_id"])
        guard selectedHardware.isEmpty || selectedHardware == explicitlySelectedHardware else {
            throw RuntimeFailure("RECORDER_IDENTITY","Recorder identity could not be verified.")
        }
        candidates[identifier]?.removeValue(forKey:"compat_token")
        candidates[identifier]?.removeValue(forKey:"identity_timeout")
        waiting = "pairing"; busy = true
        do { try ownership.confirmOperationPeripheral(id:identifier,name:name,selectedHardware:selectedHardware) }
        catch { ownership.fail(error.localizedDescription); throw error }
    }
    func ownershipReadIdentity() { readIdentity(afterAuth:true) }
    func onBleError(_ errorCode: Int32) { status = "Recorder connection error (\(errorCode))."; busy = false }
    func onAuthSuccess() {
        guard store.state().signedIn, waiting == "auth", connected else { return }
        deadline?.cancel(); waiting = ""; busy = false
        do { try ownership.accepted() } catch { ownership.fail(error.localizedDescription) }
    }
    func ownershipReady() {
        deadline?.cancel(); waiting = "state"; authorized = true; busy = true; recordStateKnown = false; status = "Checking recorder status"
        automatic = false
        explicitlySelectedHardware = ""
        candidates[identifier]?["key_rejected"] = false
        store.rememberRecorder(identifier,name)
        send { self.sdk.getRecordStatus() }; send { self.sdk.getBattery() }; send { self.sdk.syncTime() }
        timeout("Recorder status did not arrive. Wake the recorder and reconnect.",disconnect:true)
    }
    func onAuthFailed() {
        guard store.state().signedIn, waiting == "auth", connected else { return }
        deadline?.cancel(); waiting = ""; busy = false; authorized = false; cancelAutomatic()
        candidates[identifier]?["key_rejected"] = true
        ownershipAuthRejected = true
        do { try ownership.rejected() } catch { ownership.fail(error.localizedDescription) }
    }
    func onDeviceMac(_ mac: String) {
        guard store.state().signedIn, ["identity","confirm_identity","identity_consent","registration_identity"].contains(waiting), connected else { return }
        identityRead?.cancel(); deadline?.cancel(); waiting = ""; busy = false
        candidates[identifier]?.removeValue(forKey:"compat_token")
        candidates[identifier]?.removeValue(forKey:"identity_timeout")
        if authorized, ownership.state == "authorized", (try? RecorderOwnership.canonical(mac)) == nil {
            status = "This recorder did not return a hardware ID. Recording and syncing are still available."; return
        }
        do { try ownership.identity(mac,id:identifier,name:name) } catch { ownership.fail(error.localizedDescription) }
    }
    func ownershipKey(_ key: String) {
        waiting = "auth"; busy = true; status = "Connected. Checking device key…"
        send { self.sdk.bindDevice(key) }
        timeout("Recorder authorization timed out. Check the original key.",seconds:15,disconnect:true)
    }
    func ownershipChanged() { status = ownership.message; busy = ownership.requesting || ownership.running }
    func ownershipClose(_ message: String) {
        ownershipReconnectPending = false; ownershipSeeking = false; status = message; disconnectReason = message; authorized = false; waiting = ""; busy = false
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
    }
    func ownershipReconnect() {
        guard store.state().signedIn else { return }
        if let peripheral { ownershipReconnectPending = true; central.cancelPeripheralConnection(peripheral) }
        else if let device = discovered[identifier] { reconnectOwnership(device) }
        else { ownershipSeek() }
    }
    private func reconnectOwnership(_ device: CBPeripheral) {
        let generation = requestGeneration
        Task {
            try? await Task.sleep(nanoseconds:700_000_000)
            guard generation == requestGeneration, store.state().signedIn else { return }
            peripheral = device; identifier = device.identifier.uuidString; probeOnly = false; busy = true; waiting = ""; authorized = false
            central.connect(device); timeout("Connection timed out. Check your recorder and try again.",disconnect:true)
        }
    }
    func ownershipSeek() {
        if automatic, let device = peripheral {
            autoProbing = true; disconnectReason = "Your last recorder is unavailable. Wake it up and try again."
            central.cancelPeripheralConnection(device); return
        }
        if let device = peripheral { ownershipSeeking = true; central.cancelPeripheralConnection(device); return }
        startOwnershipScan()
    }
    private func startOwnershipScan() {
        busy = false; waiting = ""
        Task { do { try await command(.scan,id:"",name:"") } catch { ownership.fail(error.localizedDescription) } }
    }
    func ownershipUnbind() {
        ownershipReconnectPending = true; waiting = "rotate"; busy = true
        send { self.sdk.unbindDevice() }; timeout("Recorder did not confirm the authorization change. Continue the pending operation.",disconnect:false)
    }
    func ownershipInventory() {
        authorized = true; ownershipListing = true; ownershipEntries = []; files = []; directories = []; waiting = "ownership_state"; busy = true
        send { self.sdk.getRecordStatus() }; timeout("Recorder status did not arrive. Wake the recorder and reconnect.",disconnect:true)
    }
    private func startOwnershipListing() { waiting = ""; phase = "idle"; recordStateKnown = true; send { self.sdk.getFileDirs() }; timeout("The recorder file list did not arrive.") }
    func onBatteryLevel(_ level: Int32) { battery = level >= 0 && level <= 100 ? "\(level)%" : "Not received" }
    static func isStoppedReply(_ raw: Int, fileName: String?, seconds: Int) -> Bool {
        raw == 0 || (raw == 3 || raw == 4) && fileName == "0" && seconds == 0
    }
    func onRecordStateReply(_ state: JWDRecordState, fileName: String?, currentTime: Int) {
        guard authorized, connected else { return }
        let value = state.rawValue
        if waiting == "registration_identity", Self.isStoppedReply(value,fileName:fileName,seconds:currentTime) { return }
        if value < 0 { deadline?.cancel(); waiting = ""; busy = false; phase = "interrupted"; status = "The recorder reported an error. Check storage and the physical recorder."; return }
        recordStateKnown = true
        if Self.isStoppedReply(value,fileName:fileName,seconds:currentTime) {
            if ownershipListing, waiting == "ownership_state" { startOwnershipListing(); return }
            if phase == "saving" { return }
            let shouldSync = waiting == "stop" || waiting == "state" || ["recording","paused","stopping","interrupted"].contains(phase)
            accumulated = elapsed; recordStarted = nil; deadline?.cancel(); waiting = ""; busy = false; phase = "idle"
            status = "Recorder stopped"
            if shouldSync, store.state().signedIn { scheduleSync() } else { recordName = "" }
        } else {
            if ownership.running { ownership.fail("Stop recording before changing recorder ownership."); return }
            if waiting == "start", let fileName, !fileName.isEmpty {
                let elapsed = Double(currentTime)
                let timestamp = (0...15).contains(elapsed) ? Date().addingTimeInterval(-elapsed) : nil
                store.rememberRecorderStart(identifier,fileName,folder:startFolder,recordedAt:timestamp)
            }
            deadline?.cancel(); waiting = ""; busy = false
            if let fileName, !fileName.isEmpty { recordName = fileName }
            if phase != "paused" { accumulated = Int64(max(0,currentTime)) * 1000; recordStarted = ProcessInfo.processInfo.systemUptime; phase = "recording" }
            status = phase == "paused" ? "Recorder paused" : "Recording on your recorder"
        }
    }
    func onRecordStateCheck(_ status: Int32) {
        guard authorized, connected else { return }
        if ownershipListing, waiting == "ownership_state" {
            if status == 0 { startOwnershipListing() } else { ownership.fail("Stop recording before changing recorder ownership.") }; return
        }
        if status == 0 && (waiting.isEmpty || waiting == "state") && !receiving && phase != "saving" {
            let shouldSync = waiting == "state" || ["recording","paused","stopping","interrupted"].contains(phase)
            deadline?.cancel(); waiting = ""; busy = false; recordStateKnown = true
            accumulated = elapsed; phase = "idle"; recordStarted = nil; self.status = "Recorder connected"
            if shouldSync, store.state().signedIn { scheduleSync() } else { recordName = "" }
        } else if status == 1 {
            waiting = "state"; busy = true; send { self.sdk.getRecordInfo() }
            timeout("Recorder status did not arrive. Wake the recorder and reconnect.",disconnect:true)
        }
    }
    func onRecordPaused() {
        guard authorized, connected else { return }
        accumulated = elapsed; recordStarted = nil; phase = "paused"; waiting = ""; busy = false
        deadline?.cancel(); status = "Recorder paused"
    }
    func onRecordResumed() {
        guard authorized, connected else { return }
        recordStarted = ProcessInfo.processInfo.systemUptime; phase = "recording"; waiting = ""; busy = false
        deadline?.cancel(); status = "Recording on your recorder"
    }
    func onRecordStream(_ data: Data) {
        // Discard live PCM. The verified saved file is the sole transcription source.
    }
    private func scheduleSync() {
        guard !ownership.blocked else { return }
        phase = "saving"; busy = true; status = "Preparing to sync recording"
        let generation = connectionGeneration, owner = store.scope
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard generation == connectionGeneration, owner == store.scope,
                  authorized, connected, store.state().signedIn,
                  phase == "saving", !receiving else { return }
            beginSync()
        }
    }
    private func beginSync(folder: String = "") {
        guard !ownership.blocked else { return }
        syncFolder = folder
        phase = "saving"; busy = true; directories = []; files = []; transferQueue = []
        status = "Reading recorder files"; send { self.sdk.getFileDirs() }; timeout("The recorder file list did not arrive.")
    }
    func onFileDirs(_ dirs: [String], total: Int32) {
        guard authorized, (ownershipListing || phase == "saving"), dirs.count == Int(total), Set(dirs).count == dirs.count, dirs.allSatisfy({safeName($0)}) else { transferError("Folder list is incomplete. Refresh it."); return }
        directories = dirs; deadline?.cancel(); listNext()
    }
    private func safeName(_ value: String) -> Bool { !value.isEmpty && value.count < 240 && !value.contains("&") && !value.contains("..") && !value.contains("/") && !value.contains("\\") }
    private func listNext() {
        if !directories.isEmpty { let dir = directories.removeFirst(); listingDirectory = dir; send { self.sdk.getDirFiles(dir) }; timeout("The recorder file list did not arrive."); return }
        if ownershipListing { ownershipListing = false; ownershipReading = true; transferQueue = files; nextTransfer(); return }
        transferQueue = files.filter { (($0["duration"] as? Int) ?? 0) <= 3600 }
        nextTransfer()
    }
    func onDirFiles(_ list: [JWDFileInfo], dir: String, total: Int32) {
        guard authorized, dir == listingDirectory, list.count == Int(total), Set(list.map{$0.fileName}).count == list.count, list.allSatisfy({safeName($0.fileName)}) else { transferError("File list is incomplete. Load it again."); return }
        deadline?.cancel()
        files.append(contentsOf:list.filter { safeName($0.fileName) }.map { ["dir":dir,"name":$0.fileName,"duration":$0.duration] })
        listNext()
    }
    private func nextTransfer() {
        guard authorized, store.state().signedIn else { busy = false; phase = "idle"; return }
        if transferQueue.isEmpty {
            if ownershipReading { ownershipReading = false; do { try ownership.inventory(ownershipEntries) } catch { ownership.fail(error.localizedDescription) }; return }
            busy = false; receiving = false; phase = "idle"; recordName = ""; status = "Recordings saved on this phone"; return
        }
        transferGeneration += 1
        transfer = transferQueue.removeFirst(); transferOwner = store.scope; expected = 0; received = 0; receiving = true; busy = true
        status = "Downloading " + string(transfer?["name"])
        send { self.sdk.importFile(string(self.transfer?["dir"]),fileName:string(self.transfer?["name"])) }
        timeout("The transfer did not start. The original stays on your recorder.", seconds:30)
    }
    func onTransStart(_ fileName: String, fileLen: Int) {
        guard receiving, fileName == string(transfer?["name"]), fileLen > 0, fileLen <= 100 * 1024 * 1024 else { transferError("Invalid recorder file length."); return }
        do {
            expected = Int64(fileLen); received = 0
            transferCRC = 0
            transferHash = SHA256()
            transferFile = try store.directory().appendingPathComponent(UUID().uuidString + ".part")
            FileManager.default.createFile(atPath:transferFile!.path,contents:nil,attributes:[.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication])
            transferHandle = try FileHandle(forWritingTo:transferFile!)
            timeout("Transfer stalled. Retry from the original on your recorder.", seconds:30)
        } catch { transferError(error.localizedDescription) }
    }
    func onFileData(_ data: Data, fileName: String) {
        guard receiving, expected > 0, fileName == string(transfer?["name"]),
              let handle = transferHandle, received + Int64(data.count) <= expected else {
            transferError("Unexpected or excess recorder audio. No upload was queued."); return
        }
        do {
            try handle.write(contentsOf:data)
            transferCRC = StrictAudio.updateCRC32(transferCRC, bytes:data)
            transferHash.update(data:data)
            received += Int64(data.count)
            timeout("Transfer stalled. The original stays on your recorder.", seconds:30)
        }
        catch { transferError(error.localizedDescription) }
    }
    func onTransEvent(_ event: Int32, crc32: String?) {
        guard receiving else { return }
        guard event == 1, received == expected, expected > 0, let input = transferFile,
              let entry = transfer, let handle = transferHandle else {
            transferError("Recorder transfer was incomplete. No upload was queued."); return
        }
        deadline?.cancel()
        let crc = String(format:"%08X", transferCRC)
        if let crc32, !crc32.isEmpty, crc32.uppercased() != crc {
            transferError("The recorder checksum did not match. No upload was queued."); return
        }
        do {
            try handle.synchronize(); try handle.close(); transferHandle = nil
            let size = try input.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard Int64(size) == expected else {
                transferError("Recorder transfer was incomplete. No upload was queued."); return
            }
        }
        catch { transferError(error.localizedDescription); return }
        let digest = transferHash.finalize().map { String(format:"%02x",$0) }.joined()
        let owner = transferOwner, deviceId = identifier, note = store.notes("jwd:" + identifier + "|" + string(entry["name"]))
        let destination = syncFolder
        let generation = transferGeneration
        status = "Verifying complete recording"
        Task {
            do {
                guard generation == transferGeneration, owner == store.scope else { return }
                if ownershipReading {
                    ownershipEntries.append(string(entry["dir"]) + "/" + string(entry["name"]) + "|" + String((entry["duration"] as? Int) ?? 0) + "|" + digest)
                    discardTransfer(); nextTransfer(); return
                }
                let signature = deviceId + "|" + string(entry["dir"]) + "|" + string(entry["name"]) + "|" + crc
                let stableId = "jwd-" + SHA256.hash(data:Data(signature.utf8)).map { String(format:"%02x",$0) }.joined()
                guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED","Sign in to the original account to sync.") }
                if (try? store.draft(stableId)) == nil {
                    let header = try FileHandle(forReadingFrom:input); let first = try header.read(upToCount:12) ?? Data(); try header.close()
                    let isWave = first.starts(with:Data("RIFF".utf8)), isMp3 = first.starts(with:Data("ID3".utf8)) || (first.count > 1 && first[0] == 0xFF && first[1] & 0xE0 == 0xE0)
                    var draft = try store.newDraft(string(entry["name"]),ext:isMp3 ? "mp3" : "wav",id:stableId)
                    let capture = store.recorderStart(deviceId,string(entry["name"]))
                    draft["folder_id"] = capture["folder_id"] ?? destination
                    if let started = capture["recorded_at"] { draft["recorded_at"] = started }
                    let output = URL(fileURLWithPath:string(draft["path"]))
                    if isWave || isMp3 { try FileManager.default.copyItem(at:input,to:output) }
                    else { try await Task.detached(priority:.userInitiated) { try StrictAudio.decodeOpus(input,output:output) }.value }
                    guard generation == transferGeneration, owner == store.scope else { try? FileManager.default.removeItem(at:output); return }
                    let duration = try await AVURLAsset(url:output).load(.duration).seconds
                    guard duration.isFinite, duration > 0, duration <= 3600 else {
                        try? FileManager.default.removeItem(at:output); throw RuntimeFailure("INVALID_AUDIO","Recorder audio is invalid or longer than 60 minutes.")
                    }
                    draft["duration_ms"] = Int64(duration * 1000); draft["notes"] = note
                    draft["template_id"] = store.preferences.string(forKey:"note.template." + store.scope + ".jwd:" + deviceId + "|" + string(entry["name"])) ?? "@default"
                    try store.generationOptions(&draft,from:store.recorderOptions("jwd:" + deviceId + "|" + string(entry["name"])))
                    draft["source"] = "jwd_ble"; draft["jwd_device"] = deviceId; draft["jwd_file"] = string(entry["name"])
                    if !ownership.hardware.isEmpty {
                        let identity = ownership.hardware + "\n" + string(entry["dir"]) + "\n" + string(entry["name"]) + "\n" + digest
                        draft["upload_client_id"] = "jwd-" + SHA256.hash(data:Data(identity.utf8)).map { String(format:"%02x",$0) }.joined()
                    }
                    draft["validation"] = (crc32 ?? "").isEmpty ? "length + end marker (firmware supplied no CRC)" : "length + end marker + CRC32"
                    try store.save(draft); saved(stableId)
                }
                store.clearRecorderStart(deviceId,string(entry["name"]))
                lastDraft = stableId; discardTransfer(); nextTransfer()
            } catch { if generation == transferGeneration { transferError(error.localizedDescription) } }
        }
    }
    private func transferError(_ message: String) {
        sdk.cancelImport(); discardTransfer(); transferQueue.removeAll(); busy = false; phase = "idle"; status = message
        if ownership.running { ownershipListing = false; ownershipReading = false; ownership.fail(message) }
    }
    private func discardTransfer() {
        transferGeneration += 1
        deadline?.cancel(); try? transferHandle?.close(); transferHandle = nil
        if let transferFile { try? FileManager.default.removeItem(at:transferFile) }
        transferFile = nil; receiving = false; transfer = nil
    }
    func state() -> DeviceState {
        DeviceState(connected:connected,authorized:authorized,scanning:central?.isScanning ?? false,busy:busy,receiving:receiving,
            receivedBytes:received,expectedBytes:expected,identifier:identifier,name:name,battery:battery,status:status,
            candidatesJson:jsonString(Array(candidates.values).sorted { ($0["rssi"] as? Int ?? -200) > ($1["rssi"] as? Int ?? -200) }),filesJson:jsonString(files))
    }
}

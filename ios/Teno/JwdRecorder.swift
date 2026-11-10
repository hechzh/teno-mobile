import Foundation
import CoreBluetooth
import CryptoKit
import Security
import AVFoundation
import JwdVtrSDK

/// CoreBluetooth belongs to the host. Vendor callbacks only describe acknowledged hardware state.
@MainActor final class JwdRecorder: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate,
    JWDBleConnectDelegate, JWDAuthDelegate, JWDRecordStateDelegate, JWDBatteryDelegate, JWDFileMgrDelegate {
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
    private var scanTimer: Task<Void,Never>?, earlySelection: Task<Void,Never>?
    private var requestGeneration = 0
    private var deadline: Task<Void,Never>?
    private var commands: [() -> Void] = []
    private var draining = false
    private var connectionGeneration = 0
    private(set) var authorized = false, busy = false, receiving = false
    private(set) var identifier = "", name = "", battery = "Not received"
    private(set) var status = "Connect your recorder to get started.", phase = "idle", recordName = "", lastDraft = ""
    private var recordStarted: TimeInterval?, accumulated: Int64 = 0
    private var waiting = ""
    var preview: LivePreview?
    private var directories: [String] = [], files: [JSONObject] = [], transferQueue: [JSONObject] = []
    private var transfer: JSONObject?, transferFile: URL?, transferHandle: FileHandle?
    private var transferOwner = ""
    private var transferGeneration = 0
    private var expected: Int64 = 0, received: Int64 = 0
    var connected: Bool { peripheral?.state == .connected }
    var active: Bool { ["starting","recording","paused","stopping","saving","interrupted"].contains(phase) }
    var elapsed: Int64 { accumulated + (recordStarted.map { Int64((ProcessInfo.processInfo.systemUptime - $0) * 1000) } ?? 0) }
    var localId: String { recordName.isEmpty ? lastDraft : "jwd:" + identifier + "|" + recordName }
    init(store: NativeStore, api: SessionTransport, saved: @escaping (String) -> Void) {
        self.store = store; self.api = api; self.saved = saved; super.init()
        JWDClient.setDebugMode(false)
        sdk.bleConnectDelegate = self; sdk.authDelegate = self; sdk.recordStateDelegate = self
        sdk.batteryDelegate = self; sdk.fileMgrDelegate = self
        identifier = store.preferences.string(forKey: "recorder.id") ?? ""
        name = store.preferences.string(forKey: "recorder.name") ?? ""
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
            waiting = ""; busy = false; status = message
            if phase == "starting" || phase == "stopping" { phase = "interrupted" }
            if receiving || phase == "saving" { discardTransfer(); phase = "idle" }
            if disconnect, let peripheral { central.cancelPeripheralConnection(peripheral) }
        }
    }
    private func send(_ work: @escaping () -> Void) {
        commands.append(work)
        guard !draining else { return }
        draining = true; let generation = connectionGeneration
        Task {
            defer { draining = false }
            while !commands.isEmpty, connected, generation == connectionGeneration {
                let command = commands.removeFirst(); command()
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
            if generation != connectionGeneration { commands.removeAll() }
        }
    }
    func command(_ action: DeviceAction, id: String, name: String) async throws {
        if action == .disconnect {
            requestGeneration += 1; cancelAutomatic(); central?.stopScan()
            if let peripheral { central?.cancelPeripheralConnection(peripheral) }
            status = "Disconnected"; return
        }
        let generation = requestGeneration
        initializeBluetooth()
        let until = Date().addingTimeInterval(30)
        while central.state == .unknown || central.state == .resetting {
            guard generation == requestGeneration else { return }
            guard Date() < until else { throw RuntimeFailure("BLUETOOTH", "Bluetooth is not ready. Allow access and try again.") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard generation == requestGeneration else { return }
        if action == .scan || action == .compatibilityScan {
            guard central.state == .poweredOn else { throw RuntimeFailure("BLUETOOTH", "Turn on Bluetooth and allow Teno access in iOS Settings.") }
            guard !connected && !busy else { throw RuntimeFailure("DEVICE_BUSY", "Finish the current device operation first.") }
            cancelAutomatic(); automatic = true; candidates.removeAll(); autoTried.removeAll()
            preferred = store.preferences.string(forKey: "recorder.id") ?? ""
            central.scanForPeripherals(withServices: nil, options: nil)
            status = "Searching for your JWD recorder"
            earlySelection = Task { try? await Task.sleep(nanoseconds: 4_000_000_000); if !Task.isCancelled && !candidates.isEmpty { selectAutomatic() } }
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
            if action == .connect, try store.deviceKey(selected).isEmpty { throw RuntimeFailure("DEVICE_KEY", "Enter the original device key or bind a new unbound recorder.") }
            central.stopScan(); peripheral = device; identifier = selected; self.name = name.isEmpty ? device.name ?? "Recorder" : name
            probeOnly = action == .probe; busy = true; authorized = false; status = "Checking recorder service"
            central.connect(device); timeout("Connection timed out. Check your recorder and try again.", disconnect: true); return
        }
        guard authorized else { throw RuntimeFailure("DEVICE_DISCONNECTED", "Connect your recorder first.") }
        if action == .cancelTransfer { sdk.cancelImport(); discardTransfer(); phase = "idle"; busy = false; status = "Transfer paused. The original stays on your recorder."; return }
        guard !busy else { throw RuntimeFailure("DEVICE_BUSY", "Wait for the recorder to respond.") }
        switch action {
        case .refresh:
            send { self.sdk.getBattery() }
            if phase != "paused" { send { self.sdk.getRecordInfo() } }
        case .start:
            guard !active else { throw RuntimeFailure("RECORDING_ACTIVE", "Check the existing recording before starting another.") }
            waiting = "start"; busy = true; phase = "starting"; lastDraft = ""; recordName = ""
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
            guard !active, store.state().signedIn else { throw RuntimeFailure("SYNC", "Stop the recording and sign in before syncing.") }
            beginSync()
        default: break
        }
    }
    private func cancelAutomatic() {
        automatic = false; autoProbing = false
        autoQueue.removeAll(); scanTimer?.cancel(); earlySelection?.cancel()
    }
    private func selectAutomatic() {
        guard automatic, !autoProbing, !busy else { return }
        central.stopScan(); scanTimer?.cancel(); earlySelection?.cancel()
        if !preferred.isEmpty {
            if discovered[preferred] == nil, let id = UUID(uuidString: preferred) {
                discovered[preferred] = central.retrievePeripherals(withIdentifiers: [id]).first
            }
            autoQueue = [preferred]
        } else {
            autoQueue = Self.connectionOrder(Array(candidates.values), previous:"")
        }
        nextAutomaticProbe()
    }
    private func nextAutomaticProbe() {
        guard automatic else { return }
        while !autoQueue.isEmpty {
            let id = autoQueue.removeFirst()
            guard autoTried.insert(id).inserted, let device = discovered[id] else { continue }
            autoProbing = true; probeOnly = true; busy = true; authorized = false
            peripheral = device; identifier = id; name = device.name ?? "JWD recorder"
            status = "Verifying recorder protocol"
            central.connect(device)
            timeout("Connection timed out. Wake your recorder and try again.", disconnect: true)
            return
        }
        automatic = false; busy = false
        status = preferred.isEmpty ? "No JWD recorder found. Wake your recorder and try again." : "Your last recorder is unavailable. Wake it up and try again."
    }
    static func candidateName(_ value: String) -> Bool {
        let name = value.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ["VTR","H10","H11","HQ10","HQ11","HQ-10_P","HQ-11_P","HQ-10_HW","KIOLO","DEX_"].contains { name.hasPrefix($0) }
    }
    static func connectionOrder(_ values: [JSONObject], previous: String) -> [String] {
        if !previous.isEmpty { return [previous] }
        return values.filter { string($0["gatt_status"]) != "unsupported" }.sorted {
            ($0["rssi"] as? Int ?? -200) > ($1["rssi"] as? Int ?? -200)
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
        guard string(candidates[id]?["gatt_status"]) == "verified" else { throw RuntimeFailure("DEVICE_UNVERIFIED", "Check the recording service first.") }
        var credential = key
        if createNew {
            guard try store.deviceKey(id).isEmpty else { throw RuntimeFailure("DEVICE_KEY", "This recorder already has a saved key. Use the original key.") }
            let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
            var bytes = [UInt8](repeating: 0, count: 64)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw RuntimeFailure("RANDOM", "Could not create a device key.") }
            // Rejection sampling prevents modulo bias.
            credential = String(bytes.filter { $0 < 248 }.prefix(16).map { alphabet[Int($0) % 62] })
            guard credential.count == 16 else { throw RuntimeFailure("RANDOM", "Please try creating the device key again.") }
        }
        try store.saveDeviceKey(id, credential)
        try await command(.connect, id: id, name: name)
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
        let id = peripheral.identifier.uuidString
        guard let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name, !name.isEmpty else { return }
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        guard id == preferred || services.contains(Self.service) || Self.candidateName(name) else { return }
        guard candidates.count < 40 || candidates[id] != nil else { return }
        discovered[id] = peripheral
        var candidate = candidates[id] ?? ["gatt_status": "unknown"]
        candidate["address"] = id; candidate["name"] = name; candidate["rssi"] = RSSI
        candidate["has_key"] = !((try? store.deviceKey(id)) ?? "").isEmpty; candidates[id] = candidate
        if automatic && id == preferred && !busy { selectAutomatic() }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard self.peripheral === peripheral, busy else { central.cancelPeripheralConnection(peripheral); return }; verify(peripheral)
    }
    private func verify(_ device: CBPeripheral) {
        peripheral = device; busy = true; authorized = false
        device.delegate = self; device.discoverServices([Self.service])
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.peripheral === peripheral, busy else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else { unsupported(peripheral); return }
        peripheral.discoverCharacteristics(Self.characteristics, for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.peripheral === peripheral, busy else { return }
        guard error == nil, let chars = service.characteristics, Self.characteristics.allSatisfy({ id in chars.contains { $0.uuid == id } }) else { unsupported(peripheral); return }
        guard chars.contains(where: { $0.uuid == Self.characteristics[1] && (!$0.properties.intersection([.write,.writeWithoutResponse]).isEmpty) }),
              Self.characteristics.filter({ $0 != Self.characteristics[1] }).allSatisfy({ id in chars.contains { $0.uuid == id && $0.properties.contains(.notify) } }) else { unsupported(peripheral); return }
        let id = peripheral.identifier.uuidString
        candidates[id] = ["address":id,"name":peripheral.name ?? "Recorder","gatt_status":"verified","has_key": !((try? store.deviceKey(id)) ?? "").isEmpty]
        if automatic && autoProbing {
            do {
                if try store.deviceKey(id).isEmpty { try store.saveDeviceKey(id,Self.newDeviceCode()) }
                candidates[id]?["has_key"] = true
                automatic = false; autoProbing = false; probeOnly = false
                status = "Connecting automatically"; sdk.onPeripheralConnected(peripheral)
            } catch {
                cancelAutomatic(); busy = false; status = "The device code could not be saved. Try connecting again."
                central.cancelPeripheralConnection(peripheral)
            }
        } else if probeOnly {
            deadline?.cancel(); busy = false; status = "Recording service verified. Connect using your device key."
            central.cancelPeripheralConnection(peripheral)
        } else { sdk.onPeripheralConnected(peripheral) }
    }
    private func unsupported(_ device: CBPeripheral) {
        candidates[device.identifier.uuidString]?["gatt_status"] = "unsupported"
        deadline?.cancel(); busy = false; status = "This device does not expose the required recording service."
        central.cancelPeripheralConnection(device)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { disconnected(peripheral,error:error) }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { disconnected(peripheral,error:error) }
    private func disconnected(_ device: CBPeripheral,error: Error?) {
        guard peripheral?.identifier == device.identifier else { return }
        let continueSelection = automatic && autoProbing
        autoProbing = false
        sdk.onPeripheralDisconnected(device,error:error); connectionGeneration += 1; commands.removeAll()
        deadline?.cancel(); authorized = false; busy = false; peripheral = nil
        if active { accumulated = elapsed; recordStarted = nil; phase = "interrupted"; status = "Connection interrupted. The recorder may still be recording." }
        else if !probeOnly { status = "Recorder disconnected" }
        preview?.close(); discardTransfer()
        if continueSelection { nextAutomaticProbe() }
        else if candidates[identifier]?["key_rejected"] as? Bool == true { status = "Device key was rejected. Use the original key; the recorder was not reset." }
    }
    func onBleConnected(_ peripheral: CBPeripheral) {
        // Some vendor versions report readiness before the second CCCD completes.
        Task {
            for _ in 0..<40 {
                guard connected else { return }
                let notifications = peripheral.services?.flatMap { $0.characteristics ?? [] }.filter { $0.uuid == Self.characteristics[0] || $0.uuid == Self.characteristics[2] } ?? []
                if notifications.count == 2 && notifications.allSatisfy({ $0.isNotifying }) {
                    if waiting == "auth" || authorized { return }
                    do {
                        let key = try store.deviceKey(identifier)
                        guard !key.isEmpty else { throw RuntimeFailure("DEVICE_KEY","The original device key is required.") }
                        waiting = "auth"; status = "Authorizing recorder"; send { self.sdk.bindDevice(key) }
                        timeout("Recorder authorization timed out. Check the original key.", disconnect: true)
                    } catch { status = error.localizedDescription; central.cancelPeripheralConnection(peripheral) }
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            status = "Recorder notifications are unavailable."; central.cancelPeripheralConnection(peripheral)
        }
    }
    func onBleDisConnected(_ peripheral: CBPeripheral) {}
    func onBleError(_ errorCode: Int32) { status = "Recorder connection error (\(errorCode))."; busy = false }
    func onAuthSuccess() {
        guard waiting == "auth", connected else { return }
        deadline?.cancel(); waiting = ""; authorized = true; busy = false; status = "Recorder connected"
        candidates[identifier]?["key_rejected"] = false
        store.preferences.set(identifier,forKey:"recorder.id"); store.preferences.set(name,forKey:"recorder.name")
        send { self.sdk.getRecordInfo() }; send { self.sdk.getBattery() }; send { self.sdk.syncTime() }
    }
    func onAuthFailed() {
        deadline?.cancel(); waiting = ""; busy = false; authorized = false; cancelAutomatic()
        candidates[identifier]?["key_rejected"] = true
        status = "Device key was rejected. Use the original key; the recorder was not reset."
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
    }
    func onBatteryLevel(_ level: Int32) { battery = level >= 0 && level <= 100 ? "\(level)%" : "Not received" }
    func onRecordStateReply(_ state: JWDRecordState, fileName: String?, currentTime: Int) {
        let value = state.rawValue
        if value < 0 { deadline?.cancel(); waiting = ""; busy = false; phase = "interrupted"; status = "The recorder reported an error. Check storage and the physical recorder."; return }
        if value == 0 {
            let stoppedByUs = waiting == "stop"
            accumulated = elapsed; recordStarted = nil; deadline?.cancel(); waiting = ""; busy = false; phase = "idle"
            preview?.finish(); status = "Recorder stopped"
            if stoppedByUs, store.state().signedIn { beginSync() } else { recordName = "" }
        } else {
            let newlyStarted = waiting == "start" || phase == "idle" || phase == "interrupted"
            deadline?.cancel(); waiting = ""; busy = false
            if let fileName, !fileName.isEmpty { recordName = fileName }
            if phase != "paused" { accumulated = Int64(max(0,currentTime)) * 1000; recordStarted = ProcessInfo.processInfo.systemUptime; phase = "recording" }
            status = phase == "paused" ? "Recorder paused" : "Recording on your recorder"
            if newlyStarted, store.state().signedIn, store.livePreview {
                preview = LivePreview(api: api,id:"jwd-" + UUID().uuidString,title:recordName)
            }
        }
    }
    func onRecordStateCheck(_ status: Int32) {
        if status == 0 && waiting.isEmpty && !receiving { phase = "idle"; recordName = ""; recordStarted = nil }
        else if status == 1 { send { self.sdk.getRecordInfo() } }
    }
    func onRecordPaused() {
        accumulated = elapsed; recordStarted = nil; phase = "paused"; waiting = ""; busy = false
        deadline?.cancel(); status = "Recorder paused"; preview?.pause(true)
    }
    func onRecordResumed() {
        recordStarted = ProcessInfo.processInfo.systemUptime; phase = "recording"; waiting = ""; busy = false
        deadline?.cancel(); status = "Recording on your recorder"; preview?.pause(false)
    }
    func onRecordStream(_ data: Data) { if phase == "recording" { preview?.feed(data) } }
    private func beginSync() {
        phase = "saving"; busy = true; directories = []; files = []; transferQueue = []
        status = "Reading recorder files"; send { self.sdk.getFileDirs() }; timeout("The recorder file list did not arrive.")
    }
    func onFileDirs(_ dirs: [String], total: Int32) {
        directories = dirs.filter { safeName($0) }; deadline?.cancel(); listNext()
    }
    private func safeName(_ value: String) -> Bool { !value.isEmpty && value.count < 240 && !value.contains("&") && !value.contains("..") && !value.contains("/") && !value.contains("\\") }
    private func listNext() {
        if !directories.isEmpty { let dir = directories.removeFirst(); send { self.sdk.getDirFiles(dir) }; timeout("The recorder file list did not arrive."); return }
        transferQueue = files.filter { (($0["duration"] as? Int) ?? 0) <= 3600 }
        nextTransfer()
    }
    func onDirFiles(_ list: [JWDFileInfo], dir: String, total: Int32) {
        deadline?.cancel()
        files.append(contentsOf:list.filter { safeName($0.fileName) }.map { ["dir":dir,"name":$0.fileName,"duration":$0.duration] })
        listNext()
    }
    private func nextTransfer() {
        guard authorized, store.state().signedIn else { busy = false; phase = "idle"; return }
        if transferQueue.isEmpty { busy = false; receiving = false; phase = "idle"; recordName = ""; status = "Recordings saved on this phone"; return }
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
            transferFile = try store.directory().appendingPathComponent(UUID().uuidString + ".part")
            FileManager.default.createFile(atPath:transferFile!.path,contents:nil,attributes:[.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication])
            transferHandle = try FileHandle(forWritingTo:transferFile!)
            timeout("Transfer stalled. Retry from the original on your recorder.", seconds:30)
        } catch { transferError(error.localizedDescription) }
    }
    func onFileData(_ data: Data, fileName: String) {
        guard receiving, expected > 0, fileName == string(transfer?["name"]), received + Int64(data.count) <= expected else { transferError("Unexpected or excess recorder audio. No upload was queued."); return }
        do { try transferHandle?.write(contentsOf:data); received += Int64(data.count); timeout("Transfer stalled. The original stays on your recorder.", seconds:30) }
        catch { transferError(error.localizedDescription) }
    }
    func onTransEvent(_ event: Int32, crc32: String?) {
        guard receiving else { return }
        guard event == 1, received == expected, expected > 0, let input = transferFile, let entry = transfer else {
            transferError("Recorder transfer was incomplete. No upload was queued."); return
        }
        deadline?.cancel()
        do { try transferHandle?.synchronize(); try transferHandle?.close(); transferHandle = nil }
        catch { transferError(error.localizedDescription); return }
        let owner = transferOwner, deviceId = identifier, note = store.notes("jwd:" + identifier + "|" + string(entry["name"]))
        let generation = transferGeneration
        status = "Verifying complete recording"
        Task {
            do {
                let crc = try await Task.detached(priority:.userInitiated) { try StrictAudio.crc32(input) }.value
                guard generation == transferGeneration else { return }
                if let crc32, !crc32.isEmpty, crc32.uppercased() != crc { throw RuntimeFailure("FILE_CRC","The recorder checksum did not match. No upload was queued.") }
                let signature = deviceId + "|" + string(entry["dir"]) + "|" + string(entry["name"]) + "|" + crc
                let stableId = "jwd-" + SHA256.hash(data:Data(signature.utf8)).map { String(format:"%02x",$0) }.joined()
                guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED","Sign in to the original account to sync.") }
                if (try? store.draft(stableId)) == nil {
                    let header = try FileHandle(forReadingFrom:input); let first = try header.read(upToCount:12) ?? Data(); try header.close()
                    let isWave = first.starts(with:Data("RIFF".utf8)), isMp3 = first.starts(with:Data("ID3".utf8)) || (first.count > 1 && first[0] == 0xFF && first[1] & 0xE0 == 0xE0)
                    var draft = try store.newDraft(string(entry["name"]),ext:isMp3 ? "mp3" : "wav",id:stableId)
                    let output = URL(fileURLWithPath:string(draft["path"]))
                    if isWave || isMp3 { try FileManager.default.copyItem(at:input,to:output) }
                    else { try await Task.detached(priority:.userInitiated) { try StrictAudio.decodeOpus(input,output:output) }.value }
                    guard generation == transferGeneration, owner == store.scope else { try? FileManager.default.removeItem(at:output); return }
                    let duration = try await AVURLAsset(url:output).load(.duration).seconds
                    guard duration.isFinite, duration > 0, duration <= 3600 else {
                        try? FileManager.default.removeItem(at:output); throw RuntimeFailure("INVALID_AUDIO","Recorder audio is invalid or longer than 60 minutes.")
                    }
                    draft["duration_ms"] = Int64(duration * 1000); draft["notes"] = note
                    draft["source"] = "jwd_ble"; draft["jwd_device"] = deviceId; draft["jwd_file"] = string(entry["name"])
                    draft["validation"] = (crc32 ?? "").isEmpty ? "length + end marker (firmware supplied no CRC)" : "length + end marker + CRC32"
                    try store.save(draft); saved(stableId)
                }
                lastDraft = stableId; discardTransfer(); nextTransfer()
            } catch { if generation == transferGeneration { transferError(error.localizedDescription) } }
        }
    }
    private func transferError(_ message: String) {
        sdk.cancelImport(); discardTransfer(); transferQueue.removeAll(); busy = false; phase = "idle"; status = message
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
            candidatesJson:jsonString(Array(candidates.values.filter { string($0["gatt_status"]) == "verified" }).sorted { string($0["name"]) < string($1["name"]) }),filesJson:jsonString(files))
    }
}

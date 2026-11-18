import XCTest
@testable import Teno

private final class FixtureProtocol: URLProtocol {
    static var respond: ((URLRequest) throws -> (Int,JSONObject))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code,value) = try Self.respond!(request)
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:code,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:try jsonData(value)); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self,didFailWithError:error) }
    }
    override func stopLoading() {}
}

final class PersonalRuntimeTests: XCTestCase {
    @MainActor func testProcessingLanguageFreezeRestartAndNextFile() throws {
        let (store,_) = try fixture(); store.identity("processing-082","fixture")
        store.preferences.set("zh",forKey:"interface_locale")
        var draft = try store.newDraft("语言测试",ext:"txt"); store.freezeGeneration(&draft); try store.save(draft)
        XCTAssertEqual(string(draft["output_language"]),"zh-CN")
        store.preferences.set("en",forKey:"interface_locale"); store.freezeGeneration(&draft)
        XCTAssertEqual(string(draft["output_language"]),"zh-CN")
        var restored = try store.draft(string(draft["id"])); store.freezeGeneration(&restored)
        XCTAssertEqual(string(restored["output_language"]),"zh-CN")
        var next = try store.newDraft("Next",ext:"txt"); store.freezeGeneration(&next)
        XCTAssertEqual(string(next["output_language"]),"en-US")
        var override = try store.newDraft("Override",ext:"txt")
        try store.generationOptions(&override,from:["output_language":"zh-CN","output_language_origin":"override"]);store.freezeGeneration(&override)
        XCTAssertEqual(string(override["output_language"]),"zh-CN")
        var following = try store.newDraft("Following",ext:"txt");store.freezeGeneration(&following)
        XCTAssertEqual(string(following["output_language"]),"en-US")
    }
    @MainActor func testOldUnsubmittedDraftGetsLanguageOnceButRemoteJobDoesNot() throws {
        let (store,_) = try fixture(); store.identity("migration-082","fixture")
        store.preferences.set("zh",forKey:"interface_locale")
        let local = try store.newDraft("Local",ext:"txt");try store.save(local)
        var remote = try store.newDraft("Remote",ext:"txt"); remote["recording_id"] = "already-uploaded";try store.save(remote)
        let migrated = store.drafts();XCTAssertEqual(string(migrated.first { string($0["id"]) == string(local["id"]) }?["output_language"]),"zh-CN")
        XCTAssertNil(migrated.first { string($0["id"]) == string(remote["id"]) }?["output_language"])
        store.preferences.set("en",forKey:"interface_locale")
        XCTAssertEqual(string(store.drafts().first { string($0["id"]) == string(local["id"]) }?["output_language"]),"zh-CN")
    }
    @MainActor func testLoggedOutRecorderRejectsNativeCommandsBeforeBluetooth() async throws {
        let (store,api) = try fixture()
        let recorder = JwdRecorder(store:store,api:api,saved:{ _ in })
        for action in [DeviceAction.scan,.compatibilityScan,.probe,.connect] {
            do { try await recorder.command(action,id:"",name:""); XCTFail("Expected sign-in guard") }
            catch let error as RuntimeFailure { XCTAssertEqual(error.code,"SIGN_IN") }
        }
        do { try await recorder.bind(id:UUID().uuidString,name:"Fixture",key:"1234567890123456",createNew:false); XCTFail("Expected sign-in guard") }
        catch let error as RuntimeFailure { XCTAssertEqual(error.code,"SIGN_IN") }
        recorder.cancelAccountConnection(); recorder.onAuthSuccess()
        XCTAssertFalse(recorder.authorized); XCTAssertFalse(recorder.busy)
    }
    @MainActor private func fixture() throws -> (NativeStore,SessionTransport) {
        let name = "com.teno.test." + UUID().uuidString
        let preferences = UserDefaults(suiteName:name)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let vault = KeyVault(service:name)
        addTeardownBlock { preferences.removePersistentDomain(forName:name); try? vault.set("session",nil); try? FileManager.default.removeItem(at:folder) }
        let store = try NativeStore(preferences:preferences,root:folder,vault:vault); store.base = "https://fixture.invalid"
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [FixtureProtocol.self]
        return (store,SessionTransport(store,session:URLSession(configuration:configuration)))
    }
    @MainActor func testLogin401IsCredentialsAndDoesNotRetainTokens() async throws {
        let (store,api) = try fixture()
        let bodies: [JSONObject] = [["code":"INVALID_CREDENTIALS","message":"Invalid username or password."],[:]]
        for body in bodies {
            FixtureProtocol.respond = { _ in (401,body) }
            do { try await api.login(server:store.base,username:"fixture",password:" fixture "); XCTFail("Expected failure") }
            catch let error as RuntimeFailure { XCTAssertEqual(error.code,"INVALID_CREDENTIALS"); XCTAssertFalse(error.message.contains("expired")) }
            XCTAssertFalse(store.state().signedIn); XCTAssertEqual(try store.token("access_token"),"")
        }
    }
    @MainActor func testPostLoginSessionFailureKeepsItsMeaning() async throws {
        let (store,api) = try fixture()
        FixtureProtocol.respond = { request in
            request.url!.path.hasSuffix("/login") ? (200,["access_token":"fixture","refresh_token":"fixture-refresh"]) : (401,["code":"UNAUTHORIZED"])
        }
        do { try await api.login(server:store.base,username:"fixture",password:"fixture"); XCTFail("Expected expired session") }
        catch let error as RuntimeFailure { XCTAssertEqual(error.code,"UNAUTHORIZED"); XCTAssertNotEqual(error.code,"INVALID_CREDENTIALS") }
        XCTAssertFalse(store.state().signedIn)
    }
    @MainActor func testCloudDefaultsOnAndExplicitOffSurvivesAccountSwitch() throws {
        let (store,_) = try fixture()
        store.identity("first","one"); XCTAssertTrue(store.cloudUpload); XCTAssertFalse(store.optionsSet)
        store.configure(cloud:false,wifi:true,live:false)
        store.identity("second","two"); XCTAssertTrue(store.cloudUpload)
        store.identity("first","one"); XCTAssertFalse(store.cloudUpload); XCTAssertTrue(store.wifiOnly)
    }
    @MainActor func testSuccessfulLoginDoesNotRewriteAccountLanguagePreferences() async throws {
        let (store,api) = try fixture(); var methods: [String] = []
        FixtureProtocol.respond = { request in
            methods.append(request.httpMethod! + " " + request.url!.path)
            if request.url!.path.hasSuffix("/login") { return (200,["access_token":"fixture","refresh_token":"fixture-refresh"]) }
            if request.httpMethod == "GET", request.url!.path == "/api/v1/me" {
                return (200,["id":"fixture-user","settings":["language":"auto","summary_language":"zh-CN","timezone":"Asia/Shanghai"]])
            }
            return (500,["code":"UNEXPECTED_REQUEST"])
        }
        try await api.login(server:store.base,username:"fixture",password:"fixture")
        XCTAssertTrue(store.state().signedIn)
        XCTAssertEqual(methods,["POST /api/v1/auth/login","GET /api/v1/me"])
    }
    @MainActor func testSecureDeviceCodeAndLastDevicePolicy() throws {
        let (store,_) = try fixture()
        store.identity("owner","one")
        let code = try JwdRecorder.newDeviceCode()
        XCTAssertNotNil(code.range(of:"^[A-Za-z0-9]{16}$",options:.regularExpression))
        let identifier = UUID().uuidString
        try store.saveDeviceKey(identifier,code); XCTAssertEqual(try store.deviceKey(identifier),code)
        let scope = store.scope
        try store.logout(); XCTAssertEqual(try store.deviceKey(identifier),"")
        store.identity("other","two"); XCTAssertEqual(try store.deviceKey(identifier),"")
        store.identity("owner","one"); XCTAssertEqual(try store.deviceKey(identifier),code)
        try store.vault.set("device." + scope + "." + identifier,nil)
        let devices: [JSONObject] = [["address":"weak","rssi":-80],["address":"strong","rssi":-30],["address":"fake","rssi":-10,"gatt_status":"unsupported"]]
        XCTAssertEqual(JwdRecorder.connectionOrder(devices,previous:""),["strong","weak"])
        XCTAssertEqual(JwdRecorder.connectionOrder(devices,previous:"weak"),["weak"])
        XCTAssertTrue(JwdRecorder.candidateName("HQ-10_P_909DBB57")); XCTAssertFalse(JwdRecorder.candidateName("AirPods"))
    }
    @MainActor func testDocumentsRemainFilesAndLocalDraftsStayAccountScoped() throws {
        let (store,_) = try fixture()
        XCTAssertEqual(NativeImportCoordinator.kind("pdf"),"file"); XCTAssertNil(NativeImportCoordinator.kind("exe"))
        XCTAssertTrue(UploadQueue.remote(["file_id":"file-fixture"])); XCTAssertFalse(UploadQueue.remote(["id":"local"]))
        store.identity("first","one"); let draft = try store.newDraft("Fixture",ext:"txt"); try store.save(draft)
        store.identity("second","two"); XCTAssertTrue(store.drafts().isEmpty); XCTAssertThrowsError(try store.save(draft))
        store.identity("first","one"); XCTAssertEqual(store.drafts().count,1)
    }
    @MainActor func testLegacyLivePreferenceCannotEnableRecordingTimeTranscription() throws {
        let (store,api) = try fixture()
        store.preferences.set(true,forKey:"live_default")
        XCTAssertFalse(store.livePreview); XCTAssertFalse(store.state().livePreview)
        store.configure(cloud:false,wifi:true,live:true)
        XCTAssertFalse(store.livePreview); XCTAssertFalse(store.cloudUpload); XCTAssertTrue(store.wifiOnly)
        let recorder = JwdRecorder(store:store,api:api,saved:{ _ in XCTFail("A live packet must not become a saved recording") })
        let before = store.drafts().count
        recorder.onRecordStream(Data(repeating:0,count:3200))
        XCTAssertEqual(store.drafts().count,before)
    }
    @MainActor func testIdleRTReplyIsNotMistakenForAnActiveRecording() {
        XCTAssertTrue(JwdRecorder.isStoppedReply(3,fileName:"0",seconds:0))
        XCTAssertTrue(JwdRecorder.isStoppedReply(0,fileName:nil,seconds:0))
        XCTAssertFalse(JwdRecorder.isStoppedReply(3,fileName:"recording.opus",seconds:0))
        XCTAssertFalse(JwdRecorder.isStoppedReply(1,fileName:"recording.opus",seconds:0))
    }
    @MainActor func testProtocolIdentityAndCompleteFileHashAreIndependentOfNamesAndOrder() throws {
        XCTAssertEqual(try RecorderOwnership.canonical("a0:b1:c2:d3:e4:f5"),"A0B1C2D3E4F5")
        XCTAssertEqual(try RecorderOwnership.canonical("A0-B1-C2-D3-E4-F5"),"A0B1C2D3E4F5")
        XCTAssertThrowsError(try RecorderOwnership.canonical("VTR7860_P_8CBEDB9C"))
        XCTAssertThrowsError(try RecorderOwnership.canonical("000000000000"))
        let first = ["folder/a.wav|2|hashA","folder/b.wav|3|hashB"]
        XCTAssertEqual(RecorderOwnership.inventoryHash(first),RecorderOwnership.inventoryHash(Array(first.reversed())))
        XCTAssertNotEqual(RecorderOwnership.inventoryHash(first),RecorderOwnership.inventoryHash(["folder/a.wav|2|changed","folder/b.wav|3|hashB"]))
        let (store,api) = try fixture(); store.identity("owner","one")
        let upload = UploadQueue(store:store,api:api)
        XCTAssertEqual(upload.fields(["id":"local-file","upload_client_id":"jwd-verified-file"]).first?.1,"jwd-verified-file")
    }
    @MainActor func testSameAccountRecoveryUsesServerKeyOnlyAfterVerifiedIdentity() async throws {
        let (store,api) = try fixture(); store.identity("owner","one"); try store.saveTokens(["access_token":"fixture"])
        let recorder: JSONObject = ["id":"owned-card","hardware_id":"A0B1C2D3E4F5","name":"VTR7860_P_8CBEDB9C","epoch":3]
        var requests: [String] = []
        FixtureProtocol.respond = { request in
            requests.append(request.url!.path)
            if request.url!.path.hasSuffix("/resolve") { return (200,["state":"owned","recorder":recorder]) }
            if request.url!.path.hasSuffix("/restore") { return (200,recorder.merging(["device_key":"OriginalCode1234"]){_,new in new}) }
            return (500,[:])
        }
        let controller=RecorderOwnership(store:store,api:api),port=OwnershipFixturePort(); controller.port=port
        try controller.identity("a0:b1:c2:d3:e4:f5",id:"new-phone-peripheral",name:"Renamed recorder")
        for _ in 0..<200 { if !port.keys.isEmpty { break }; try await Task.sleep(nanoseconds:10_000_000) }
        XCTAssertEqual(port.keys,["OriginalCode1234"]); XCTAssertEqual(requests,["/api/v1/recorders/resolve","/api/v1/recorders/owned-card/restore"])
        XCTAssertEqual(try store.deviceKey("new-phone-peripheral"),"OriginalCode1234")
        XCTAssertFalse(port.ready); try controller.accepted(); XCTAssertTrue(port.ready)
        store.identity("other","two"); XCTAssertEqual(try store.deviceKey("new-phone-peripheral"),"")
    }
    @MainActor func testUnownedAndForeignCardsNeverReceiveAnAutomaticNewCode() async throws {
        let (store,api) = try fixture(); store.identity("owner","one"); try store.saveTokens(["access_token":"fixture"])
        for result in ["claim_required","transfer_required"] {
            FixtureProtocol.respond = { _ in (200,["state":result]) }
            let controller=RecorderOwnership(store:store,api:api),port=OwnershipFixturePort();controller.port=port
            try controller.identity("A0B1C2D3E4F5",id:"candidate",name:"VTR7860_P_8CBEDB9C")
            for _ in 0..<200 { if controller.state==result { break }; try await Task.sleep(nanoseconds:10_000_000) }
            XCTAssertEqual(controller.state,result);XCTAssertTrue(port.keys.isEmpty);XCTAssertFalse(port.ready)
        }
    }
}

@MainActor private final class OwnershipFixturePort: RecorderOwnershipPort {
    var keys: [String] = [], ready=false
    func ownershipKey(_ key: String){keys.append(key)}
    func ownershipReconnect(){}
    func ownershipInventory(){}
    func ownershipUnbind(){}
    func ownershipReady(){ready=true}
    func ownershipChanged(){}
    func ownershipClose(_ message: String){}
    func ownershipSeek(){}
}

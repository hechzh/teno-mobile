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
        store.identity("first","one"); XCTAssertTrue(store.cloudUpload)
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
        let code = try JwdRecorder.newDeviceCode()
        XCTAssertNotNil(code.range(of:"^[A-Za-z0-9]{16}$",options:.regularExpression))
        let identifier = UUID().uuidString
        try store.saveDeviceKey(identifier,code); XCTAssertEqual(try store.deviceKey(identifier),code)
        try store.logout(); XCTAssertEqual(try store.deviceKey(identifier),code)
        try store.vault.set("device." + identifier,nil)
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
    @MainActor func testPreviewConnectionDoesNotClaimRecorderAudioHasArrived() {
        XCTAssertEqual(JwdRecorder.audioPreviewStatus(connection:"Live",bytes:0,elapsed:2,silence:2),"Waiting for recorder audio · Transcription connected")
        XCTAssertTrue(JwdRecorder.audioPreviewStatus(connection:"Live",bytes:0,elapsed:11,silence:11).hasPrefix("No live audio"))
        XCTAssertTrue(JwdRecorder.audioPreviewStatus(connection:"Live",bytes:640,elapsed:20,silence:11).hasPrefix("Recorder audio interrupted"))
        XCTAssertEqual(JwdRecorder.audioPreviewStatus(connection:"Live",bytes:640,elapsed:2,silence:0),"Live")
    }
    @MainActor func testIdleRTReplyIsNotMistakenForAnActiveRecording() {
        XCTAssertTrue(JwdRecorder.isStoppedReply(3,fileName:"0",seconds:0))
        XCTAssertTrue(JwdRecorder.isStoppedReply(0,fileName:nil,seconds:0))
        XCTAssertFalse(JwdRecorder.isStoppedReply(3,fileName:"recording.opus",seconds:0))
        XCTAssertFalse(JwdRecorder.isStoppedReply(1,fileName:"recording.opus",seconds:0))
    }
}

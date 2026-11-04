import XCTest
@testable import Teno

final class RuntimeTests: XCTestCase {
    @MainActor func testBridgeErrorsKeepTheMessageWithoutStackDetails() async {
        do {
            let _: Void = try await bridgeOperation { throw RuntimeFailure("MICROPHONE_PERMISSION", "Allow microphone access in Settings.") }
            XCTFail("The failed operation must stay failed")
        } catch let error as PigeonError {
            XCTAssertEqual(error.code,"MICROPHONE_PERMISSION")
            XCTAssertEqual(error.message,"Allow microphone access in Settings.")
            XCTAssertNil(error.details)
        } catch { XCTFail("Expected a typed bridge error") }
    }
    func testRecordingRecoveryRepairsHeaderWithoutDroppingCommittedSamples() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at:path) }
        var bytes = Data(count:44); bytes.append(Data(repeating:7,count:640)); bytes.append(0)
        try bytes.write(to:path)
        XCTAssertEqual(try PCMFile.recover(path),640)
        let result = try Data(contentsOf:path)
        XCTAssertEqual(result.count,684); XCTAssertEqual(result.prefix(4),Data("RIFF".utf8))
        XCTAssertEqual(result.suffix(640),Data(repeating:7,count:640))
    }
    func testBadFinalOpusNeverBecomesAnUploadableWave() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let input = dir.appendingPathComponent("damaged.opus"), output = dir.appendingPathComponent("decoded.wav")
        try Data(repeating:255,count:79).write(to:input)
        XCTAssertThrowsError(try StrictAudio.decodeOpus(input,output:output))
        XCTAssertFalse(FileManager.default.fileExists(atPath:output.path))
    }
    func testChecksumMatchesKnownVector() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:path) }
        try Data("123456789".utf8).write(to:path)
        XCTAssertEqual(try StrictAudio.crc32(path),"CBF43926")
    }
    @MainActor func testServerCannotRedirectCredentialsToEmbeddedAuthority() throws {
        XCTAssertThrowsError(try SessionTransport.validateBase("https://user:password@example.com"))
        XCTAssertThrowsError(try SessionTransport.validateBase("http://example.com"))
        XCTAssertThrowsError(try SessionTransport.validateBase("https://example.com/api"))
        XCTAssertEqual(try SessionTransport.validateBase("https://example.com/"),"https://example.com")
        let transport = SessionTransport(try NativeStore())
        XCTAssertThrowsError(try transport.makeRequest("GET","//example.com/api/v1/me",token:""))
        XCTAssertThrowsError(try transport.makeRequest("GET","/api/v1/../secret",token:""))
    }
}

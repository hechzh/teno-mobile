import Foundation
import ImageIO
import Vision

// A successful simctl launch is not proof that Flutter has painted its first frame.
// Capture the actual simulator and wait for the fresh-install sign-in screen.
let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("Usage: capture_ios.swift DEVICE OUTPUT.png") }
let device = arguments[1], file = URL(fileURLWithPath: arguments[2])
let deadline = Date().addingTimeInterval(60)
var ready = false
repeat {
    let process = Process()
    process.executableURL = URL(fileURLWithPath:"/usr/bin/xcrun")
    process.arguments = ["simctl","io",device,"screenshot",file.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run(); process.waitUntilExit()
    if process.terminationStatus == 0,
       let source = CGImageSourceCreateWithURL(file as CFURL,nil),
       let image = CGImageSourceCreateImageAtIndex(source,0,nil) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage:image).perform([request])
        let strings = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string.lowercased() }
        ready = strings.contains(where:{ $0 == "teno" }) && strings.contains(where:{ $0 == "sign in" })
        if ready { break }
    }
    Thread.sleep(forTimeInterval:2)
} while Date() < deadline
guard ready else {
    fputs("Teno sign-in screen did not render within 60 seconds. Inspect the saved simulator screenshot.\n",stderr)
    exit(1)
}
print("Teno sign-in screen verified from the native simulator screenshot.")

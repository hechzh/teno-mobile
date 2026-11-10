import Foundation

/// Preview only. Complete audio is always uploaded through the persistent queue.
@MainActor final class LivePreview {
    private let api: SessionTransport
    private let recordingId: String
    private let title: String
    private var socket: URLSessionWebSocketTask?
    private var frames: [Data] = []
    private var bytesQueued = 0
    private var sending = false, ready = false, closed = false, stopping = false, paused = false
    private var totalBytes: Int64 = 0, baseOffset: Int64 = 0
    private var retries = 0
    private var retryTask: Task<Void,Never>?
    private var generation = 0
    var partial = "", status = "Connecting"
    var segments: [JSONObject] = []
    private var seen = Set<String>()
    init(api: SessionTransport, id: String, title: String) {
        self.api = api; recordingId = id; self.title = title.isEmpty ? "Recorder recording" : title
        Task { await connect() }
    }
    private func connect() async {
        guard !closed, !stopping else { return }
        generation += 1; let attempt = generation
        baseOffset = totalBytes / 32; frames.removeAll(); bytesQueued = 0
        do {
            let session = try await api.json("POST", "/api/v1/realtime/sessions",
                body: ["title": title, "language": "auto", "preview": true,
                    "recording_client_id": recordingId, "client_id": UUID().uuidString])
            guard attempt == generation, !closed else { return }
            let path = string(session["websocket_path"])
            guard path.hasPrefix("/api/v1/realtime/sessions/"), !path.contains("..") else {
                throw RuntimeFailure("LIVE_ROUTE", "Invalid live session address.")
            }
            var request = try api.makeRequest("GET", path)
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.scheme = components.scheme == "https" ? "wss" : "ws"
            request.url = components.url
            let task = URLSession.shared.webSocketTask(with: request)
            socket = task; task.resume()
            while !closed, generation == attempt {
                let message = try await task.receive()
                guard case .string(let text) = message, let bytes = text.data(using: .utf8) else { continue }
                var event = try jsonObject(bytes)
                switch string(event["type"]) {
                case "ready":
                    ready = true; retries = 0; status = "Live"; pump()
                    if paused { pause(true) }
                case "partial": partial = string(event["text"])
                case "final":
                    if seen.insert(string(event["id"])).inserted {
                        event["start_ms"] = (event["start_ms"] as? Int64 ?? 0) + baseOffset
                        event["end_ms"] = (event["end_ms"] as? Int64 ?? 0) + baseOffset
                        segments.append(event)
                    }
                    partial = ""
                case "completed": status = "Preview complete"; close(); return
                case "error", "interrupted":
                    let code = string(event["code"])
                    throw RuntimeFailure(code.isEmpty ? "LIVE_UNAVAILABLE" : code, code == "ASR_BUSY" ? "Transcription service busy · Complete audio is kept" : "Live preview is unavailable. Audio is still saved locally.")
                default: break
                }
            }
        } catch {
            guard !closed, generation == attempt else { return }
            status = (error as? RuntimeFailure)?.message ?? "Live preview interrupted · Complete audio is kept"
            ready = false; partial = ""; frames.removeAll(); bytesQueued = 0
            socket?.cancel(with: .goingAway, reason: nil)
            scheduleRetry()
        }
    }
    func feed(_ data: Data) {
        guard !closed, !stopping, !paused else { return }
        totalBytes += Int64(data.count)
        guard bytesQueued + data.count <= 320000 else {
            status = "Preview has gaps · Complete audio is kept"; frames.removeAll(); bytesQueued = 0; retry(); return
        }
        frames.append(data); bytesQueued += data.count; pump()
    }
    private func pump() {
        guard ready, !sending, !closed, socket != nil else { return }
        sending = true
        Task {
            defer { sending = false }
            do {
                while !frames.isEmpty, ready, !closed {
                    let frame = frames.removeFirst(); bytesQueued -= frame.count
                    try await socket?.send(.data(frame))
                }
            } catch { ready = false; status = "Live preview interrupted · Complete audio is kept"; scheduleRetry() }
        }
    }
    func pause(_ paused: Bool) {
        self.paused = paused
        partial = ""; status = paused ? "Paused" : ready ? "Live" : "Preview unavailable"
        Task { try? await socket?.send(.string(paused ? "{\"type\":\"pause\"}" : "{\"type\":\"resume\"}")) }
    }
    func retry() {
        guard !closed,!stopping else { return }
        retryTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil); frames.removeAll(); bytesQueued = 0; ready = false
        status = "Reconnecting · Preview may have gaps"; Task { await connect() }
    }
    func finish() {
        stopping = true; retryTask?.cancel()
        Task {
            for _ in 0..<40 {
                if !sending && frames.isEmpty || !ready { break }
                try? await Task.sleep(nanoseconds:50_000_000)
            }
            try? await socket?.send(.string("{\"type\":\"stop\"}"))
            try? await Task.sleep(nanoseconds: 22_000_000_000)
            close()
        }
    }
    private func scheduleRetry() {
        guard !closed,!stopping else { return }
        retryTask?.cancel(); retries += 1
        let delay = min(30,3*retries)
        retryTask = Task {
            try? await Task.sleep(nanoseconds:UInt64(delay)*1_000_000_000)
            if !Task.isCancelled { await connect() }
        }
    }
    func close() { retryTask?.cancel(); closed = true; ready = false; generation += 1; socket?.cancel(with: .normalClosure, reason: nil); frames.removeAll(); bytesQueued = 0 }
}

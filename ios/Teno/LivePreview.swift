import Foundation

/// Preview only. Complete audio is always uploaded through the persistent queue.
@MainActor final class LivePreview {
    private let api: SessionTransport
    private let recordingId: String
    private let title: String
    private var socket: URLSessionWebSocketTask?
    private var frames: [Data] = []
    private var bytesQueued = 0
    private var sending = false, ready = false, closed = false
    private var generation = 0
    var partial = "", status = "Connecting"
    var segments: [JSONObject] = []
    private var seen = Set<String>()
    init(api: SessionTransport, id: String, title: String) {
        self.api = api; recordingId = id; self.title = title
        Task { await connect() }
    }
    private func connect() async {
        guard !closed else { return }
        generation += 1; let attempt = generation
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
                let event = try jsonObject(bytes)
                switch string(event["type"]) {
                case "ready": ready = true; status = "Live"; pump()
                case "partial": partial = string(event["text"])
                case "final":
                    if seen.insert(string(event["id"])).inserted { segments.append(event) }
                    partial = ""
                case "completed": status = "Preview complete"; close(); return
                case "error", "interrupted": throw RuntimeFailure("LIVE_UNAVAILABLE", "Live preview is unavailable. Audio is still saved locally.")
                default: break
                }
            }
        } catch {
            guard !closed, generation == attempt else { return }
            status = "Live preview interrupted · Complete audio is kept"
            ready = false; partial = ""; frames.removeAll(); bytesQueued = 0
            socket?.cancel(with: .goingAway, reason: nil)
        }
    }
    func feed(_ data: Data) {
        guard !closed else { return }
        guard bytesQueued + data.count <= 320000 else {
            status = "Preview has gaps · Complete audio is kept"; frames.removeAll(); bytesQueued = 0; return
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
            } catch { ready = false; status = "Live preview interrupted · Complete audio is kept" }
        }
    }
    func pause(_ paused: Bool) {
        partial = ""; status = paused ? "Paused" : ready ? "Live" : "Preview unavailable"
        Task { try? await socket?.send(.string(paused ? "{\"type\":\"pause\"}" : "{\"type\":\"resume\"}")) }
    }
    func retry() {
        socket?.cancel(with: .goingAway, reason: nil); frames.removeAll(); bytesQueued = 0; ready = false
        status = "Reconnecting · Preview may have gaps"; Task { await connect() }
    }
    func finish() {
        Task {
            try? await socket?.send(.string("{\"type\":\"stop\"}"))
            try? await Task.sleep(nanoseconds: 22_000_000_000)
            close()
        }
    }
    func close() { closed = true; ready = false; generation += 1; socket?.cancel(with: .normalClosure, reason: nil); frames.removeAll(); bytesQueued = 0 }
}

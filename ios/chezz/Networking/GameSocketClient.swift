import Foundation

struct ServerEnvelope: Decodable {
    let type: String
    let game: GameDTO?
    let gameId: String?
    let uci: String?
    let san: String?
    let fen: String?
    let turn: String?
    let whiteTimeMs: Int?
    let blackTimeMs: Int?
    let result: String?
    let termination: String?
    let challenge: ChallengeDTO?
    let message: String?
}

actor GameSocketClient {
    private var task: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var continuation: AsyncStream<ServerEnvelope>.Continuation?
    private var connected = false

    func connect(token: String) -> AsyncStream<ServerEnvelope> {
        disconnect()
        var req = URLRequest(url: AppConfig.webSocketURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let t = session.webSocketTask(with: req)
        task = t
        connected = true
        t.resume()

        let stream = AsyncStream<ServerEnvelope> { cont in self.continuation = cont }
        // Belt-and-suspenders auth in case a proxy strips the upgrade header.
        Task { await self.sendRaw(["type": "auth", "token": token]) }
        Task { await self.readLoop(task: t) }
        return stream
    }

    func join(_ gameId: String) async { await sendRaw(["type": "join", "gameId": gameId]) }
    func move(gameId: String, uci: String) async { await sendRaw(["type": "move", "gameId": gameId, "uci": uci]) }
    func resign(gameId: String) async { await sendRaw(["type": "resign", "gameId": gameId]) }

    func disconnect() {
        connected = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation?.finish()
        continuation = nil
    }

    private func readLoop(task: URLSessionWebSocketTask) async {
        // Bind to this task: a reconnect swaps self.task, and a superseded loop must not touch
        // the new connection's stream or flags.
        while connected, self.task === task {
            do {
                let message = try await task.receive()
                guard self.task === task else { return }
                switch message {
                case .string(let s): yield(s)
                case .data(let d): if let s = String(data: d, encoding: .utf8) { yield(s) }
                @unknown default: break
                }
            } catch {
                if self.task === task {
                    continuation?.finish()
                    connected = false
                }
                return
            }
        }
    }

    private func yield(_ string: String) {
        guard let data = string.data(using: .utf8),
              let env = try? JSONDecoder().decode(ServerEnvelope.self, from: data) else { return }
        continuation?.yield(env)
    }

    private func sendRaw(_ dict: [String: String]) async {
        guard let task, let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? await task.send(.data(data))
    }
}

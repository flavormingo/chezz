import Foundation
import ChessKitEngine

struct AnalysisLine: Sendable, Equatable {
    let multipv: Int
    let scoreCP: Double?   // centipawns, side-to-move POV
    let mate: Int?         // mate in N, side-to-move POV
    let pv: [String]
    let depth: Int

    var bestMove: String? { pv.first }
}

// Serialized, one-search-at-a-time access to a single Stockfish instance; every search has a watchdog so the app never hangs.
actor StockfishEngine {
    static let shared = StockfishEngine()

    private let engine = Engine(type: .stockfish)
    private var didStart = false
    private var netsAvailable = false
    private var startTask: Task<Void, Never>?
    private var consumer: Task<Void, Never>?

    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private var bestMoveContinuation: CheckedContinuation<String?, Never>?
    private var analysisContinuation: CheckedContinuation<[AnalysisLine], Never>?
    private var analysisMode = false
    private var lines: [Int: AnalysisLine] = [:]
    private var watchdog: Task<Void, Never>?

    private static let bigNet = "nn-1111cefa1111"
    private static let smallNet = "nn-37f18f62d772"

    var isAvailable: Bool { didStart && netsAvailable }

    func start() async {
        if let startTask { await startTask.value; return }
        let task = Task { await self.performStart() }
        startTask = task
        await task.value
    }

    private func performStart() async {
        let big = Self.path(Self.bigNet)
        let small = Self.path(Self.smallNet)
        netsAvailable = (big != nil)

        if ProcessInfo.processInfo.arguments.contains("-chezz-enginelog") {
            await engine.set(loggingEnabled: true)
        }

        await engine.start(coreCount: 1, multipv: 1)
        // start() returns before the uci→readyok handshake; Engine.send() silently drops commands until the engine is running, so wait first.
        await waitUntilRunning()

        if let big { await engine.send(command: .setoption(id: "EvalFile", value: big)) }
        if let small { await engine.send(command: .setoption(id: "EvalFileSmall", value: small)) }
        // Single thread on purpose: multi-threaded Stockfish search is non-deterministic, which made
        // the same game review to different evals/accuracy each time. One thread keeps reviews
        // reproducible; strength is unaffected at the move-times/Elo caps the app uses.
        await engine.send(command: .setoption(id: "Threads", value: "1"))
        await engine.send(command: .setoption(id: "Hash", value: "64"))
        await engine.send(command: .isready)
        startConsumer()
        didStart = true
    }

    private func waitUntilRunning() async {
        for _ in 0..<400 {   // up to ~4s
            if await engine.isRunning { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func bestMove(forFEN fen: String, difficulty: AIDifficulty) async -> String? {
        await start()
        guard netsAvailable else { return nil }
        await acquire()
        defer { release() }
        await applyDifficulty(difficulty)
        await engine.send(command: .position(.fen(fen), moves: nil))
        let move = await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            bestMoveContinuation = cont
            analysisMode = false
            let cmd = EngineCommand.go(depth: difficulty.depth, movetime: difficulty.moveTimeMs)
            Task { await engine.send(command: cmd) }
            armWatchdog(timeoutMs: difficulty.moveTimeMs + 6000)
        }
        cancelWatchdog()
        return move
    }

    // Fixed node budget (device-independent) rather than depth, to keep Review snappy.
    func analyze(fen: String, nodes: Int = 40_000, multipv: Int = 2) async -> [AnalysisLine] {
        await start()
        guard netsAvailable else { return [] }
        await acquire()
        defer { release() }
        // Clear the transposition table before each position so a game reviews to identical evals
        // every run. (The engine is single-threaded, see performStart, which makes the search itself
        // deterministic; multi-threaded Stockfish is not, which caused reviews to vary run to run.)
        await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "false"))
        await engine.send(command: .setoption(id: "Skill Level", value: "20"))
        await engine.send(command: .setoption(id: "MultiPV", value: "\(multipv)"))
        await engine.send(command: .ucinewgame)
        await engine.send(command: .position(.fen(fen), moves: nil))
        lines = [:]
        let result = await withCheckedContinuation { (cont: CheckedContinuation<[AnalysisLine], Never>) in
            analysisContinuation = cont
            analysisMode = true
            Task { await engine.send(command: .go(nodes: nodes)) }
            armWatchdog(timeoutMs: 20_000)
        }
        cancelWatchdog()
        return result
    }

    func stopSearch() async { await engine.send(command: .stop) }

    private func armWatchdog(timeoutMs: Int) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeoutMs) * 1_000_000)
            if Task.isCancelled { return }
            await self?.searchTimedOut()
        }
    }
    private func cancelWatchdog() { watchdog?.cancel(); watchdog = nil }

    private func searchTimedOut() async {
        // Engine didn't answer in time; stop it and resume the caller so the lock releases and the game continues.
        guard bestMoveContinuation != nil || analysisContinuation != nil else { return }
        await engine.send(command: .stop)
        failPending()
    }

    private func acquire() async {
        if !locked { locked = true; return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in waiters.append(c) }
    }
    private func release() {
        if waiters.isEmpty { locked = false }
        else { waiters.removeFirst().resume() }
    }

    private func startConsumer() {
        consumer?.cancel()
        consumer = Task { [weak self] in
            guard let self else { return }
            guard let stream = await self.engine.responseStream else { return }
            for await response in stream {
                if Task.isCancelled { break }
                await self.handle(response)
            }
            await self.failPending()
        }
    }

    private func handle(_ response: EngineResponse) {
        switch response {
        case let .info(info):
            guard analysisMode, let mpv = info.multipv, let pv = info.pv, !pv.isEmpty else { return }
            let depth = info.depth ?? 0
            if let existing = lines[mpv], existing.depth > depth { return }
            lines[mpv] = AnalysisLine(multipv: mpv, scoreCP: info.score?.cp, mate: info.score?.mate, pv: pv, depth: depth)

        case let .bestmove(move, _):
            if analysisMode {
                analysisMode = false
                let result = lines.values.sorted { $0.multipv < $1.multipv }
                analysisContinuation?.resume(returning: result)
                analysisContinuation = nil
                lines = [:]
            } else {
                let best = (move == "(none)" || move.isEmpty) ? nil : move
                bestMoveContinuation?.resume(returning: best)
                bestMoveContinuation = nil
            }
        default:
            break
        }
    }

    private func failPending() {
        if let c = bestMoveContinuation { c.resume(returning: nil); bestMoveContinuation = nil }
        if let c = analysisContinuation { c.resume(returning: []); analysisContinuation = nil }
        analysisMode = false
        lines = [:]
    }

    private func applyDifficulty(_ d: AIDifficulty) async {
        if d.limitStrength, let elo = d.uciElo {
            await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "true"))
            await engine.send(command: .setoption(id: "UCI_Elo", value: "\(elo)"))
        } else {
            await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "false"))
            await engine.send(command: .setoption(id: "Skill Level", value: "\(d.skillLevel)"))
        }
        await engine.send(command: .setoption(id: "MultiPV", value: "1"))
    }

    private static func path(_ name: String) -> String? {
        Bundle.main.path(forResource: name, ofType: "nnue")
    }
}

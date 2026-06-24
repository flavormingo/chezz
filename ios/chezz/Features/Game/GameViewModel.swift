import SwiftUI
import Observation
import ChessKit

@MainActor
@Observable
final class GameViewModel: Identifiable {
    let id = UUID()
    let game: ChessGame
    var perspective: Side
    let settings: AppSettings

    var thinking = false
    var showResult = false
    var engineUnavailable = false

    private let engine = StockfishEngine.shared
    private var aiTask: Task<Void, Never>?

    init(timeControl: TimeControl, opponent: OpponentKind, humanColor: Side?, settings: AppSettings) {
        self.settings = settings
        self.game = ChessGame(timeControl: timeControl, opponent: opponent, humanColor: humanColor)
        self.perspective = humanColor ?? .white
        self.game.onMovePlayed = { [weak self] m in self?.handleMove(m) }
        self.game.onGameEnded = { [weak self] _ in self?.handleEnd() }
    }

    var theme: BoardTheme { settings.boardTheme }
    var topSide: Side { perspective.opposite }
    var bottomSide: Side { perspective }

    func start() {
        game.begin()
        maybeAIMove()
    }

    func stop() {
        aiTask?.cancel()
        // Only stop the shared engine if THIS game has a search in flight; a finished game
        // firing a stray .stop could otherwise clip a rematch's fresh search on the same engine.
        if thinking { Task { await engine.stopSearch() } }
    }

    func tap(_ sq: Square) { game.tap(sq) }
    func select(_ sq: Square) { game.select(sq) }
    func move(from: Square, to: Square) {
        if game.attemptMove(from: from, to: to) == .illegal {
            Feedback.play(.illegal, haptics: settings.hapticsEnabled, sound: false)
        }
    }
    func promote(_ kind: Piece.Kind) { game.completePendingPromotion(kind) }
    func cancelPromotion() { game.cancelPendingPromotion() }

    func canMoveFrom(_ sq: Square) -> Bool {
        guard game.isHumanTurn, let p = game.board.position.piece(at: sq) else { return false }
        return p.color == game.sideToMove
    }

    var legalTargetSet: Set<Square> { settings.showLegalMoves ? Set(game.legalTargets) : [] }

    func flip() { perspective = perspective.opposite }

    func resignHuman() {
        let side = game.humanColor ?? game.sideToMove
        game.resign(side)
    }

    private func handleMove(_ m: PlayedMove) {
        Feedback.play(event(for: m), haptics: settings.hapticsEnabled, sound: settings.soundEnabled)
        maybeAIMove()
    }

    private func handleEnd() {
        thinking = false
        Feedback.play(.gameEnd, haptics: settings.hapticsEnabled, sound: settings.soundEnabled)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { showResult = true }
    }

    private func event(for m: PlayedMove) -> Feedback.Event {
        if m.san.contains("#") || m.san.contains("+") { return .check }
        if m.san.contains("=") { return .promote }
        if m.san.hasPrefix("O-O") { return .castle }
        if m.san.contains("x") { return .capture }
        return .move
    }

    private func maybeAIMove() {
        guard !game.isGameOver, case let .computer(difficulty) = game.opponent,
              let human = game.humanColor, game.sideToMove != human else { return }
        thinking = true
        let fen = game.board.position.fen
        aiTask = Task { [weak self] in
            guard let self else { return }
            let started = Date()
            let uci = await engine.bestMove(forFEN: fen, difficulty: difficulty)
            // Pad the engine's (often near-instant) reply up to a difficulty-scaled floor so the
            // opponent appears to think and spends a fair share of its own clock on its turn.
            await Self.humanizeThinking(since: started, baseMs: difficulty.thinkMs)
            thinking = false
            if Task.isCancelled || game.isGameOver { return }
            if let uci, game.applyUCIMove(uci) { return }
            // Nets missing (dev build): fall back to a random legal move so the game still plays.
            engineUnavailable = true
            if let m = randomLegalMove() { game.attemptMove(from: m.0, to: m.1, promotion: .queen) }
        }
    }

    private static func humanizeThinking(since start: Date, baseMs: Int) async {
        let target = Double(baseMs) * Double.random(in: 0.85...1.15)
        let remainingMs = target - Date().timeIntervalSince(start) * 1000
        guard remainingMs > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remainingMs * 1_000_000))
    }

    private func randomLegalMove() -> (Square, Square)? {
        let stm = game.sideToMove
        var options: [(Square, Square)] = []
        for p in game.board.position.pieces where p.color == stm {
            for target in game.board.legalMoves(forPieceAt: p.square) { options.append((p.square, target)) }
        }
        return options.randomElement()
    }
}

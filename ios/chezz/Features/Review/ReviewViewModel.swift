import SwiftUI
import Observation
import ChessKit

enum FENBoard {
    static func pieces(_ fen: String) -> [Square: Piece] {
        guard let pos = Position(fen: fen) else { return [:] }
        var map: [Square: Piece] = [:]
        for p in pos.pieces { map[p.square] = p }
        return map
    }
    static func checkSquare(_ fen: String) -> Square? {
        guard let pos = Position(fen: fen) else { return nil }
        let board = Board(position: pos)
        switch board.state {
        case let .check(c): return king(c, pos)
        case let .checkmate(c): return king(c, pos)
        default: return nil
        }
    }
    static func fromTo(_ uci: String) -> (Square, Square)? {
        guard uci.count >= 4 else { return nil }
        let c = Array(uci)
        return (Square(String(c[0...1])), Square(String(c[2...3])))
    }
    private static func king(_ color: Side, _ pos: Position) -> Square? {
        pos.pieces.first { $0.kind == .king && $0.color == color }?.square
    }
}

@MainActor
@Observable
final class ReviewViewModel: Identifiable {
    let id = UUID()
    let history: [PlayedMove]
    let startFEN: String
    let result: ResultSummary?
    let whiteName: String
    let blackName: String

    var review: GameReview?
    var loading = true
    var progress: Double = 0
    var currentPly: Int = 0          // 0 = starting position; 1…N after each move
    var perspective: Side
    var showBestArrow = true

    private let engine = ReviewEngine()

    // cacheKey: when set (an archived game's id), the computed review is cached and reused so
    // re-opening the same game shows the identical result instead of re-analyzing each time.
    let cacheKey: UUID?
    // serverGameId: set for online games. Reviews are shared via the server so both players see the
    // identical analysis (on-device engine analysis isn't reproducible across devices).
    let serverGameId: String?

    init(history: [PlayedMove], startFEN: String, result: ResultSummary?,
         whiteName: String, blackName: String, perspective: Side = .white,
         cacheKey: UUID? = nil, serverGameId: String? = nil) {
        self.history = history
        self.startFEN = startFEN
        self.result = result
        self.whiteName = whiteName
        self.blackName = blackName
        self.perspective = perspective
        self.cacheKey = cacheKey
        self.serverGameId = serverGameId
    }

    var plyCount: Int { history.count }

    func load() async {
        // 1. Already computed on this device (persisted) — instant and stable.
        if let cacheKey, let cached = ReviewCache.shared.review(for: cacheKey) {
            finish(with: cached)
            return
        }
        // 2. Online games: use the shared review if a participant has already computed one.
        if let serverGameId, let remote = try? await APIClient.shared.gameReview(serverGameId) {
            finish(with: remote)
            return
        }
        // 3. Compute locally, then (for online games) publish it so the opponent sees the same one.
        let computed = await engine.run(history: history, startFEN: startFEN, result: result,
                                        progress: { p in Task { @MainActor in self.progress = p } })
        var canonical = computed
        if let serverGameId, !computed.engineUnavailable {
            canonical = (try? await APIClient.shared.uploadGameReview(serverGameId, computed)) ?? computed
        }
        finish(with: canonical)
    }

    private func finish(with r: GameReview) {
        review = r
        loading = false
        currentPly = 0
        if let cacheKey { ReviewCache.shared.save(r, for: cacheKey) }
    }

    var displayFEN: String { currentPly == 0 ? startFEN : history[currentPly - 1].fenAfter }
    var pieceMap: [Square: Piece] { FENBoard.pieces(displayFEN) }
    var checkSquare: Square? { FENBoard.checkSquare(displayFEN) }

    var lastMove: (from: Square, to: Square)? {
        guard currentPly >= 1 else { return nil }
        return FENBoard.fromTo(history[currentPly - 1].uci)
    }

    var currentMove: MoveReview? {
        guard currentPly >= 1, let review, currentPly - 1 < review.moves.count else { return nil }
        return review.moves[currentPly - 1]
    }

    var bestArrow: (from: Square, to: Square)? {
        guard showBestArrow, let review, currentPly < review.positionBestUCI.count,
              let uci = review.positionBestUCI[currentPly] else { return nil }
        return FENBoard.fromTo(uci)
    }

    var evalPct: Double { series(review?.evalWhitePctSeries, default: 50) }
    var evalCP: Double { series(review?.evalWhiteCPSeries, default: 0) }
    var evalMate: Int? { currentMove?.mateWhiteAfter }

    private func series(_ arr: [Double]?, default def: Double) -> Double {
        guard let arr, currentPly < arr.count else { return def }
        return arr[currentPly]
    }

    func goTo(_ ply: Int) { currentPly = max(0, min(plyCount, ply)) }
    func first() { currentPly = 0 }
    func last() { currentPly = plyCount }
    func next() { if currentPly < plyCount { currentPly += 1 } }
    func prev() { if currentPly > 0 { currentPly -= 1 } }

    func nextKeyMoment() {
        guard let km = review?.keyMoments else { return }
        // keyMoments are 0-based ply indices; display ply = index + 1.
        if let next = km.map({ $0 + 1 }).first(where: { $0 > currentPly }) { currentPly = next }
        else { last() }
    }
    func prevKeyMoment() {
        guard let km = review?.keyMoments else { return }
        if let prev = km.map({ $0 + 1 }).last(where: { $0 < currentPly }) { currentPly = prev }
        else { first() }
    }
}

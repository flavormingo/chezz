import Foundation
import Observation
import ChessKit

struct PlayedMove: Identifiable, Hashable {
    let id = UUID()
    let ply: Int
    let color: Side
    let san: String
    let uci: String
    let fenBefore: String
    let fenAfter: String
    let whiteClock: TimeInterval?
    let blackClock: TimeInterval?

    var moveNumber: Int { (ply + 1) / 2 }
}

enum MoveAttempt: Equatable { case moved, needsPromotion, illegal }

@MainActor
@Observable
final class ChessGame {
    private(set) var board: Board
    private(set) var history: [PlayedMove] = []
    private(set) var outcome: GameOutcome = .ongoing
    private(set) var termination: Termination?

    let timeControl: TimeControl
    let clock: ChessClock?
    let opponent: OpponentKind
    let humanColor: Side?            // side the local human controls; nil = pass & play (both sides local).
    let startDate = Date()

    var selectedSquare: Square?
    private(set) var legalTargets: [Square] = []
    private(set) var lastMove: (from: Square, to: Square)?
    private(set) var pendingPromotion: Move?
    private var pendingFenBefore: String?

    // viewPly = half-moves shown (0 = start); nil = follow the live position. Browsing is read-only.
    private(set) var viewPly: Int?
    private(set) var browsePieces: [Square: Piece] = [:]
    private(set) var browseLastMove: (from: Square, to: Square)?

    @ObservationIgnored var onMovePlayed: ((PlayedMove) -> Void)?
    @ObservationIgnored var onGameEnded: ((ResultSummary) -> Void)?

    var sideToMove: Side { board.position.sideToMove }
    var isGameOver: Bool { outcome.isOver }
    var ply: Int { history.count }
    var lastSAN: String? { history.last?.san }

    var isHumanTurn: Bool {
        guard !isGameOver, pendingPromotion == nil else { return false }
        if let human = humanColor { return sideToMove == human }
        return true
    }

    var checkedKingSquare: Square? {
        switch board.state {
        case let .check(color): return kingSquare(color)
        case let .checkmate(color): return kingSquare(color)
        default: return nil
        }
    }

    init(timeControl: TimeControl, opponent: OpponentKind, humanColor: Side?) {
        self.board = Board(position: .standard)
        self.timeControl = timeControl
        self.opponent = opponent
        self.humanColor = humanColor
        self.clock = timeControl.isUntimed ? nil : ChessClock(timeControl: timeControl)
        self.clock?.onFlag = { [weak self] side in self?.handleFlag(side) }
    }

    func begin() { clock?.start(activeSide: .white) }

    func tap(_ square: Square) {
        guard isHumanTurn else { return }
        if let sel = selectedSquare, legalTargets.contains(square) {
            _ = attemptMove(from: sel, to: square)
            return
        }
        if let piece = board.position.piece(at: square), piece.color == sideToMove {
            selectedSquare = square
            legalTargets = board.legalMoves(forPieceAt: square)
        } else {
            clearSelection()
        }
    }

    func select(_ square: Square) {
        guard isHumanTurn else { return }
        if let piece = board.position.piece(at: square), piece.color == sideToMove {
            selectedSquare = square
            legalTargets = board.legalMoves(forPieceAt: square)
        }
    }

    func clearSelection() {
        selectedSquare = nil
        legalTargets = []
    }

    var pieceMap: [Square: Piece] {
        var map: [Square: Piece] = [:]
        for piece in board.position.pieces { map[piece.square] = piece }
        return map
    }

    var isBrowsing: Bool { viewPly != nil }
    var displayPieces: [Square: Piece] { isBrowsing ? browsePieces : pieceMap }
    var displayLastMove: (from: Square, to: Square)? { isBrowsing ? browseLastMove : lastMove }

    var canStepBack: Bool { (viewPly ?? history.count) > 0 }
    var canStepForward: Bool { isBrowsing }

    var browseLabel: String {
        guard let p = viewPly else { return "Live" }
        if p == 0 { return "Start" }
        let m = history[p - 1]
        return "\(m.moveNumber)\(m.color == .white ? "." : "…") \(m.san)"
    }

    func browseFirst() { setViewPly(0) }
    func browseBack() { setViewPly((viewPly ?? history.count) - 1) }
    func browseForward() { setViewPly((viewPly ?? history.count) + 1) }
    func browseLive() { setViewPly(nil) }

    private func setViewPly(_ p: Int?) {
        guard let p, p >= 0, p < history.count else {
            viewPly = nil; browsePieces = [:]; browseLastMove = nil
            return
        }
        viewPly = p
        browsePieces = pieceMap(atPly: p)
        browseLastMove = p > 0 ? moveCoords(history[p - 1]) : nil
        clearSelection()
    }

    private func pieceMap(atPly k: Int) -> [Square: Piece] {
        if k >= history.count { return pieceMap }
        var b = Board(position: .standard)
        for m in history.prefix(k) {
            let c = Array(m.uci)
            _ = b.move(pieceAt: Square(String(c[0...1])), to: Square(String(c[2...3])))
            if case let .promotion(pm) = b.state, c.count >= 5, let kind = Piece.Kind(promotionChar: c[4]) {
                _ = b.completePromotion(of: pm, to: kind)
            }
        }
        var map: [Square: Piece] = [:]
        for p in b.position.pieces { map[p.square] = p }
        return map
    }

    private func moveCoords(_ m: PlayedMove) -> (from: Square, to: Square) {
        let c = Array(m.uci)
        return (Square(String(c[0...1])), Square(String(c[2...3])))
    }

    @discardableResult
    func attemptMove(from: Square, to: Square, promotion: Piece.Kind? = nil) -> MoveAttempt {
        guard !isGameOver, pendingPromotion == nil else { return .illegal }
        let fenBefore = board.position.fen
        guard let move = board.move(pieceAt: from, to: to) else { return .illegal }

        if case let .promotion(pm) = board.state {
            if let promotion {
                let completed = board.completePromotion(of: pm, to: promotion)
                finalize(completed, fenBefore: fenBefore)
                return .moved
            } else {
                pendingPromotion = pm
                pendingFenBefore = fenBefore
                clearSelection()
                return .needsPromotion
            }
        }
        finalize(move, fenBefore: fenBefore)
        return .moved
    }

    func completePendingPromotion(_ kind: Piece.Kind) {
        guard let pm = pendingPromotion, let fenBefore = pendingFenBefore else { return }
        let completed = board.completePromotion(of: pm, to: kind)
        pendingPromotion = nil
        pendingFenBefore = nil
        finalize(completed, fenBefore: fenBefore)
    }

    func cancelPendingPromotion() {
        // The pawn push was half-applied; rebuild from history to revert it.
        pendingPromotion = nil
        pendingFenBefore = nil
        rebuildBoardFromHistory()
    }

    @discardableResult
    func applyUCIMove(_ uci: String) -> Bool {
        guard uci.count >= 4 else { return false }
        let chars = Array(uci)
        let from = Square(String(chars[0...1]))
        let to = Square(String(chars[2...3]))
        var promo: Piece.Kind?
        if chars.count >= 5 { promo = Piece.Kind(promotionChar: chars[4]) }
        return attemptMove(from: from, to: to, promotion: promo) == .moved
    }

    private func finalize(_ move: Move, fenBefore: String) {
        let mover = move.piece.color
        clock?.didMove(mover)
        let played = PlayedMove(
            ply: history.count + 1, color: mover, san: move.san, uci: move.lan,
            fenBefore: fenBefore, fenAfter: board.position.fen,
            whiteClock: clock?.white, blackClock: clock?.black)
        history.append(played)
        lastMove = (move.start, move.end)
        clearSelection()
        viewPly = nil; browsePieces = [:]; browseLastMove = nil
        updateOutcome()
        onMovePlayed?(played)
    }

    func resign(_ side: Side) { setResult(.win(side.opposite), .resignation) }

    private func handleFlag(_ side: Side) {
        // Simplified: a flag-fall is always a loss (FIDE exempts it when the opponent can't mate).
        setResult(.win(side.opposite), .timeout)
    }

    private func updateOutcome() {
        switch board.state {
        case let .checkmate(color):
            setResult(.win(color.opposite), .checkmate)
        case let .draw(reason):
            let term: Termination
            switch reason {
            case .stalemate: term = .stalemate
            case .insufficientMaterial: term = .insufficientMaterial
            case .fiftyMoves: term = .fiftyMove
            case .repetition: term = .repetition
            case .agreement: term = .agreement
            }
            setResult(.draw, term)
        default:
            break
        }
    }

    private func setResult(_ o: GameOutcome, _ t: Termination) {
        guard !outcome.isOver else { return }
        outcome = o
        termination = t
        clock?.stop()
        clearSelection()
        onGameEnded?(ResultSummary(outcome: o, termination: t))
    }

    private func kingSquare(_ color: Side) -> Square? {
        board.position.pieces.first { $0.kind == .king && $0.color == color }?.square
    }

    private func rebuildBoardFromHistory() {
        var b = Board(position: .standard)
        for m in history {
            let chars = Array(m.uci)
            let from = Square(String(chars[0...1]))
            let to = Square(String(chars[2...3]))
            _ = b.move(pieceAt: from, to: to)
            if case let .promotion(pm) = b.state, chars.count >= 5,
               let kind = Piece.Kind(promotionChar: chars[4]) {
                _ = b.completePromotion(of: pm, to: kind)
            }
        }
        board = b
        lastMove = history.last.map {
            let c = Array($0.uci)
            return (Square(String(c[0...1])), Square(String(c[2...3])))
        }
    }

}

extension Piece.Kind {
    init?(promotionChar c: Character) {
        switch Character(c.lowercased()) {
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        default: return nil
        }
    }
}

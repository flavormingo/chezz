import Foundation
import ChessKit

struct ReviewEngine {
    let engine: StockfishEngine

    init(engine: StockfishEngine = .shared) { self.engine = engine }

    func run(history: [PlayedMove],
             startFEN: String,
             result: ResultSummary?,
             nodes: Int = 40_000,
             progress: @Sendable (Double) -> Void = { _ in }) async -> GameReview {

        guard await engine.isAvailableEnsuringStart() else {
            return Self.emptyReview(history: history, startFEN: startFEN, result: result, engineUnavailable: true)
        }

        var fens = [startFEN]
        fens.append(contentsOf: history.map { $0.fenAfter })

        var evals: [PositionEval] = []
        evals.reserveCapacity(fens.count)
        for (idx, fen) in fens.enumerated() {
            let lines = await engine.analyze(fen: fen, nodes: nodes, multipv: 2)
            evals.append(PositionEval(fen: fen, sideToMove: Self.sideToMove(fen: fen), lines: lines))
            progress(Double(idx + 1) / Double(fens.count))
        }

        return Self.build(history: history, positions: evals, result: result)
    }

    static func build(history: [PlayedMove], positions: [PositionEval], result: ResultSummary?) -> GameReview {
        let book = OpeningBook.detect(sans: history.map { $0.san })
        let bookPlies = book?.bookPlies ?? 0

        var reviews: [MoveReview] = []
        var whiteCounts: [MoveClassification: Int] = [:]
        var blackCounts: [MoveClassification: Int] = [:]
        var keyMoments: [Int] = []

        for i in history.indices {
            guard i + 1 < positions.count else { break }
            let pBefore = positions[i]
            let pAfter = positions[i + 1]
            let mover = history[i].color

            let effBefore = Self.effective(pBefore)
            let effAfter = Self.effective(pAfter)
            let winBefore = effBefore.winSTM                   // mover POV (mover is the side to move)
            let winAfter = 100 - effAfter.winSTM               // mover POV; after the move the opponent is to move, so flip
            let epl = max(0, winBefore - winAfter) / 100.0
            let accuracy = Eval.moveAccuracy(winBefore: winBefore, winAfter: winAfter)

            let bestUCI = pBefore.bestMoveUCI
            let playedUCI = history[i].uci
            let isBest = (bestUCI != nil && playedUCI == bestUCI) || epl <= 0.005
            let band: MoveClassification = isBest ? .best : MoveClassification.fromExpectedPointsLost(epl)

            let onlyMoveGap: Bool = {
                guard pBefore.lines.count >= 2 else { return false }
                let w0 = Eval.winPercent(scoreCP: pBefore.lines[0].scoreCP, mate: pBefore.lines[0].mate)
                let w1 = Eval.winPercent(scoreCP: pBefore.lines[1].scoreCP, mate: pBefore.lines[1].mate)
                return (w0 - w1) >= 12
            }()
            let sacrifice = Self.isSacrifice(mover: mover, pBefore: pBefore, pAfter: pAfter)
            let isBrilliant = epl <= 0.02 && winAfter >= 50 && winBefore <= 92 && sacrifice
            let isGreat = isBest && onlyMoveGap && winBefore > 8 && winBefore < 96
            let isMiss = (band == .mistake || band == .blunder) && winBefore >= 70

            let classification: MoveClassification = {
                if i < bookPlies { return .book }
                if isBrilliant { return .brilliant }
                if isGreat { return .great }
                if isMiss { return .miss }
                return band
            }()

            let bestSAN = bestUCI.flatMap { Self.san(forUCI: $0, fen: pBefore.fen) }
            let bestLine = Self.sans(forLine: pBefore.best?.pv ?? [], fen: pBefore.fen)
            let coach = Self.coachText(classification: classification, bestSAN: bestSAN,
                                       winBefore: winBefore, winAfter: winAfter, opening: i < bookPlies ? book?.name : nil)

            let mr = MoveReview(
                ply: i, color: mover, san: history[i].san, uci: playedUCI,
                fenBefore: pBefore.fen, fenAfter: pAfter.fen,
                classification: classification, winBefore: winBefore, winAfter: winAfter, accuracy: accuracy,
                cpWhiteAfter: effAfter.cpWhite, mateWhiteAfter: effAfter.mateWhite, evalWhitePctAfter: effAfter.winWhite,
                bestMoveUCI: bestUCI, bestMoveSAN: bestSAN, bestLineSANs: bestLine, isBest: isBest, coachText: coach)
            reviews.append(mr)

            if mover == .white { whiteCounts[classification, default: 0] += 1 }
            else { blackCounts[classification, default: 0] += 1 }

            let swing = abs(pAfter.winPctWhite - pBefore.winPctWhite)
            if [.blunder, .mistake, .miss, .brilliant, .great].contains(classification) || swing >= 18 {
                keyMoments.append(i)
            }
        }

        let evalPct = positions.map { Self.effective($0).winWhite }
        let evalCP = positions.map { Self.effective($0).cpWhite }
        let movesForAcc = reviews.map { (accuracy: $0.accuracy, color: $0.color, ply: $0.ply) }
        let acc = Eval.gameAccuracy(winWhitePOV: evalPct, moves: movesForAcc)

        return GameReview(
            moves: reviews,
            whiteAccuracy: acc.white,
            blackAccuracy: acc.black,
            whiteRating: acc.white.map { Eval.estimatedRating(accuracy: $0) },
            blackRating: acc.black.map { Eval.estimatedRating(accuracy: $0) },
            openingName: book?.name,
            evalWhitePctSeries: evalPct,
            evalWhiteCPSeries: evalCP,
            positionBestUCI: positions.map { $0.bestMoveUCI },
            whiteCounts: whiteCounts,
            blackCounts: blackCounts,
            result: result,
            keyMoments: keyMoments,
            engineUnavailable: false)
    }

    private static func emptyReview(history: [PlayedMove], startFEN: String, result: ResultSummary?, engineUnavailable: Bool) -> GameReview {
        let moves = history.map { m in
            MoveReview(ply: m.ply - 1, color: m.color, san: m.san, uci: m.uci,
                       fenBefore: m.fenBefore, fenAfter: m.fenAfter,
                       classification: .good, winBefore: 50, winAfter: 50, accuracy: 100,
                       cpWhiteAfter: 0, mateWhiteAfter: nil, evalWhitePctAfter: 50,
                       bestMoveUCI: nil, bestMoveSAN: nil, bestLineSANs: [], isBest: false, coachText: "")
        }
        return GameReview(moves: moves, whiteAccuracy: nil, blackAccuracy: nil, whiteRating: nil, blackRating: nil,
                          openingName: OpeningBook.detect(sans: history.map { $0.san })?.name,
                          evalWhitePctSeries: Array(repeating: 50, count: history.count + 1),
                          evalWhiteCPSeries: Array(repeating: 0, count: history.count + 1),
                          positionBestUCI: Array(repeating: nil, count: history.count + 1),
                          whiteCounts: [:], blackCounts: [:], result: result, keyMoments: [],
                          engineUnavailable: engineUnavailable)
    }

    static func sideToMove(fen: String) -> Side {
        let parts = fen.split(separator: " ")
        return (parts.count > 1 && parts[1] == "b") ? .black : .white
    }

    // Terminal positions emit no PV, so detect checkmate/stalemate from the board instead.
    struct Eff { let winSTM: Double; let winWhite: Double; let cpWhite: Double; let mateWhite: Int? }
    static func effective(_ p: PositionEval) -> Eff {
        if p.lines.isEmpty {
            if case .checkmate = terminalState(fen: p.fen, sideToMove: p.sideToMove) {
                // Side to move is checkmated, so it has lost.
                let stm = p.sideToMove
                return Eff(winSTM: 0,
                           winWhite: stm == .white ? 0 : 100,
                           cpWhite: stm == .white ? -Eval.mateMagnitude : Eval.mateMagnitude,
                           mateWhite: stm == .white ? -1 : 1)
            }
            // Stalemate / draw, or an engine miss on a live position: treat as equal.
            return Eff(winSTM: 50, winWhite: 50, cpWhite: 0, mateWhite: nil)
        }
        return Eff(winSTM: p.winPctSTM, winWhite: p.winPctWhite, cpWhite: p.cpWhite, mateWhite: p.mateWhite)
    }

    // ChessKit computes `Board.state` for the side that *just moved* (whose opponent is now the
    // side to move), so a position loaded straight from a FEN tests the wrong king and reports a
    // checkmated side-to-move as `.active`. Flipping the side-to-move field makes ChessKit evaluate
    // the king that's actually on the move, giving a correct checkmate/stalemate verdict while still
    // using the library's own (pin-aware) attack detection.
    static func terminalState(fen: String, sideToMove stm: Side) -> Board.State {
        let flipped = fenWithSideToMove(fen, stm == .white ? "b" : "w")
        guard let pos = Position(fen: flipped) else { return .active }
        return Board(position: pos).state
    }

    static func fenWithSideToMove(_ fen: String, _ side: String) -> String {
        var fields = fen.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 2 else { return fen }
        fields[1] = side
        return fields.joined(separator: " ")
    }

    // Sacrifice = mover is down ≥ ~2 points of material after the opponent's best reply.
    private static func isSacrifice(mover: Side, pBefore: PositionEval, pAfter: PositionEval) -> Bool {
        let netBefore = Material.net(forSide: mover, fen: pBefore.fen)
        guard let reply = pAfter.bestMoveUCI, let fenReply = fenApplying(uci: reply, to: pAfter.fen) else {
            return Material.net(forSide: mover, fen: pAfter.fen) <= netBefore - 2
        }
        return Material.net(forSide: mover, fen: fenReply) <= netBefore - 2
    }

    private static func coachText(classification: MoveClassification, bestSAN: String?,
                                  winBefore: Double, winAfter: Double, opening: String?) -> String {
        let alt = bestSAN.map { " \($0) was the engine's choice." } ?? ""
        switch classification {
        case .brilliant: return "Brilliant!! A daring sacrifice that the engine confirms is best."
        case .great:     return "Great move, essentially the only move that holds the position."
        case .best:      return "Best move."
        case .excellent: return "Excellent, almost as good as the top engine move."
        case .good:      return "A solid move."
        case .book:      return opening.map { "Book move, \($0)." } ?? "Book move, known opening theory."
        case .inaccuracy:return "Inaccurate.\(alt)"
        case .mistake:   return "A mistake that hands the opponent an edge.\(alt)"
        case .miss:      return "Missed a much stronger continuation.\(alt)"
        case .blunder:   return "Blunder, this loses significant material or the game.\(alt)"
        }
    }

    private static func tempApply(uci: String, board: inout Board) -> Move? {
        guard uci.count >= 4 else { return nil }
        let chars = Array(uci)
        let from = Square(String(chars[0...1]))
        let to = Square(String(chars[2...3]))
        guard let move = board.move(pieceAt: from, to: to) else { return nil }
        if case let .promotion(pm) = board.state {
            let kind = chars.count >= 5 ? (Piece.Kind(promotionChar: chars[4]) ?? .queen) : .queen
            return board.completePromotion(of: pm, to: kind)
        }
        return move
    }

    static func san(forUCI uci: String, fen: String) -> String? {
        guard let pos = Position(fen: fen) else { return nil }
        var b = Board(position: pos)
        return tempApply(uci: uci, board: &b)?.san
    }

    static func sans(forLine line: [String], fen: String, max: Int = 6) -> [String] {
        guard let pos = Position(fen: fen) else { return [] }
        var b = Board(position: pos)
        var out: [String] = []
        for uci in line.prefix(max) {
            guard let m = tempApply(uci: uci, board: &b) else { break }
            out.append(m.san)
        }
        return out
    }

    static func fenApplying(uci: String, to fen: String) -> String? {
        guard let pos = Position(fen: fen) else { return nil }
        var b = Board(position: pos)
        guard tempApply(uci: uci, board: &b) != nil else { return nil }
        return b.position.fen
    }
}

extension StockfishEngine {
    func isAvailableEnsuringStart() async -> Bool {
        await start()
        return isAvailable
    }
}

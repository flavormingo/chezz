import Foundation
import ChessKit

enum MoveClassification: String, CaseIterable, Codable, Hashable {
    case brilliant, great, best, excellent, good, book, inaccuracy, mistake, miss, blunder

    var label: String {
        switch self {
        case .brilliant: return "Brilliant"
        case .great: return "Great"
        case .best: return "Best"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .book: return "Book"
        case .inaccuracy: return "Inaccuracy"
        case .mistake: return "Mistake"
        case .miss: return "Miss"
        case .blunder: return "Blunder"
        }
    }

    var explanation: String {
        switch self {
        case .brilliant: return "A brilliant move, usually a daring sacrifice that turns out to be the strongest option on the board."
        case .great: return "A great find, often the only move that keeps your advantage or saves the position."
        case .best: return "The best move, exactly what the engine recommends here."
        case .excellent: return "An excellent move, just as good as the top choice in practice."
        case .good: return "A good, solid move that keeps your position healthy."
        case .book: return "A book move, well-known opening theory that's been played for ages."
        case .inaccuracy: return "A slight inaccuracy, not the best, but no real harm done."
        case .mistake: return "A mistake, this hands your opponent a meaningful advantage."
        case .miss: return "A missed opportunity, you had a much stronger move available."
        case .blunder: return "A blunder, a serious error that loses material or the game."
        }
    }

    // chess.com expected-points-lost bands (0–1). "best"/"brilliant"/"great" are decided separately.
    static func fromExpectedPointsLost(_ epl: Double) -> MoveClassification {
        switch epl {
        case ..<0.02: return .excellent
        case ..<0.05: return .good
        case ..<0.10: return .inaccuracy
        case ..<0.20: return .mistake
        default: return .blunder
        }
    }
}

struct PositionEval: Sendable, Equatable {
    let fen: String
    let sideToMove: Side
    let lines: [AnalysisLine]      // sorted by multipv (1 = best)

    var best: AnalysisLine? { lines.first }
    var bestMoveUCI: String? { best?.pv.first }

    var winPctSTM: Double { Eval.winPercent(scoreCP: best?.scoreCP, mate: best?.mate) }
    var winPctWhite: Double { sideToMove == .white ? winPctSTM : 100 - winPctSTM }

    // White-POV centipawns; mate is encoded as a large magnitude.
    var cpWhite: Double {
        guard let best else { return 0 }
        if let mate = best.mate {
            let mag = Eval.mateMagnitude - Double(abs(mate))
            let stmSigned = mate > 0 ? mag : -mag
            return sideToMove == .white ? stmSigned : -stmSigned
        }
        let cp = best.scoreCP ?? 0
        return sideToMove == .white ? cp : -cp
    }

    var mateWhite: Int? {
        guard let m = best?.mate else { return nil }
        return sideToMove == .white ? m : -m
    }
}

struct MoveReview: Identifiable, Sendable, Codable {
    let id = UUID()
    let ply: Int
    let color: Side
    let san: String
    let uci: String
    let fenBefore: String
    let fenAfter: String
    let classification: MoveClassification
    let winBefore: Double
    let winAfter: Double
    let accuracy: Double
    let cpWhiteAfter: Double
    let mateWhiteAfter: Int?
    let evalWhitePctAfter: Double
    let bestMoveUCI: String?
    let bestMoveSAN: String?
    let bestLineSANs: [String]
    let isBest: Bool
    let coachText: String

    var moveNumber: Int { (ply + 1) / 2 }

    // `id` is transient view identity, not persisted: exclude it so Codable doesn't warn about the
    // immutable-with-default property, and let each decode mint a fresh (still-unique) id.
    private enum CodingKeys: String, CodingKey {
        case ply, color, san, uci, fenBefore, fenAfter, classification
        case winBefore, winAfter, accuracy, cpWhiteAfter, mateWhiteAfter, evalWhitePctAfter
        case bestMoveUCI, bestMoveSAN, bestLineSANs, isBest, coachText
    }
}

struct GameReview: Sendable, Codable {
    var moves: [MoveReview]
    var whiteAccuracy: Double?
    var blackAccuracy: Double?
    var whiteRating: Int?
    var blackRating: Int?
    var openingName: String?
    var evalWhitePctSeries: [Double]   // one entry per position, length = plies + 1
    var evalWhiteCPSeries: [Double]
    var positionBestUCI: [String?]
    var whiteCounts: [MoveClassification: Int]
    var blackCounts: [MoveClassification: Int]
    var result: ResultSummary?
    var keyMoments: [Int]
    var engineUnavailable: Bool = false

    func counts(for side: Side) -> [MoveClassification: Int] { side == .white ? whiteCounts : blackCounts }
    func accuracy(for side: Side) -> Double? { side == .white ? whiteAccuracy : blackAccuracy }
    func rating(for side: Side) -> Int? { side == .white ? whiteRating : blackRating }
}

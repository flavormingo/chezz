import Foundation
import ChessKit

// Win% uses the Lichess logistic; accuracy uses Lichess constants; classification bands use chess.com thresholds. See memory chezz-review-algorithm.
enum Eval {
    // A mate counts as this many centipawns so win% saturates near 0/100.
    static let mateMagnitude = 10_000.0

    static func winPercent(cp: Double) -> Double {
        let clamped = max(-mateMagnitude, min(mateMagnitude, cp))
        let chances = 2.0 / (1.0 + exp(-0.00368208 * clamped)) - 1.0
        return 50.0 + 50.0 * max(-1.0, min(1.0, chances))
    }

    static func winPercent(scoreCP: Double?, mate: Int?) -> Double {
        if let mate { return mate > 0 ? 100.0 : (mate < 0 ? 0.0 : 50.0) }
        if let cp = scoreCP { return winPercent(cp: cp) }
        return 50.0
    }

    // winBefore/winAfter are from the mover's POV.
    static func moveAccuracy(winBefore: Double, winAfter: Double) -> Double {
        if winAfter >= winBefore { return 100.0 }
        let diff = winBefore - winAfter
        let raw = 103.1668100711649 * exp(-0.04354415386753951 * diff) - 3.166924740191411
        return max(0.0, min(100.0, raw + 1.0))
    }

    static func stdev(_ values: ArraySlice<Double>) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }

    // Lichess game accuracy: the average of a volatility-weighted mean and a harmonic mean of per-move accuracies.
    static func gameAccuracy(winWhitePOV: [Double],
                             moves: [(accuracy: Double, color: Side, ply: Int)]) -> (white: Double?, black: Double?) {
        guard winWhitePOV.count > 1 else { return (nil, nil) }
        let windowSize = max(2, min(8, winWhitePOV.count / 10))
        var volatility = [Double](repeating: 0, count: winWhitePOV.count)
        for i in winWhitePOV.indices {
            let lo = max(0, i - windowSize + 1)
            let w = winWhitePOV[lo...i]
            volatility[i] = min(12.0, max(0.5, stdev(w)))
        }

        func accuracy(for color: Side) -> Double? {
            let these = moves.filter { $0.color == color }
            guard !these.isEmpty else { return nil }
            var weightSum = 0.0, weighted = 0.0, harmonicDen = 0.0
            for m in these {
                let w = volatility[min(m.ply + 1, volatility.count - 1)]
                let acc = max(1.0, m.accuracy)
                weightSum += w
                weighted += w * acc
                harmonicDen += 1.0 / acc
            }
            let weightedMean = weightSum > 0 ? weighted / weightSum : 100
            let harmonicMean = Double(these.count) / harmonicDen
            return (weightedMean + harmonicMean) / 2.0
        }
        return (accuracy(for: .white), accuracy(for: .black))
    }

    // Rough heuristic, not an official performance rating.
    static func estimatedRating(accuracy: Double) -> Int {
        let a = max(0, min(100, accuracy))
        let elo = (a * a / 100.0) * 20.0 + 300.0
        return Int((max(250, min(2950, elo)) / 10).rounded() * 10)
    }
}

enum Material {
    static let value: [Piece.Kind: Int] = [.pawn: 1, .knight: 3, .bishop: 3, .rook: 5, .queen: 9, .king: 0]

    static func net(forSide side: Side, fen: String) -> Int {
        guard let placement = fen.split(separator: " ").first else { return 0 }
        var score = 0
        for ch in placement where ch != "/" {
            if let digit = ch.wholeNumberValue { _ = digit; continue }
            let isWhite = ch.isUppercase
            let kind: Piece.Kind?
            switch Character(ch.lowercased()) {
            case "p": kind = .pawn
            case "n": kind = .knight
            case "b": kind = .bishop
            case "r": kind = .rook
            case "q": kind = .queen
            case "k": kind = .king
            default: kind = nil
            }
            guard let k = kind, let v = value[k] else { continue }
            let signedFor = (isWhite == (side == .white)) ? v : -v
            score += signedFor
        }
        return score
    }
}

import Foundation
import ChessKit

struct ArchivedGame: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let whiteName: String
    let blackName: String
    let humanColor: Side?
    let opponentLabel: String
    let timeControl: TimeControl
    let outcome: GameOutcome
    let termination: Termination
    let startFEN: String
    let moves: [Archived]

    struct Archived: Codable, Hashable {
        let ply: Int
        let color: Side
        let san: String
        let uci: String
        let fenBefore: String
        let fenAfter: String
        let whiteClock: TimeInterval?
        let blackClock: TimeInterval?
    }

    var history: [PlayedMove] {
        moves.map {
            PlayedMove(ply: $0.ply, color: $0.color, san: $0.san, uci: $0.uci,
                       fenBefore: $0.fenBefore, fenAfter: $0.fenAfter,
                       whiteClock: $0.whiteClock, blackClock: $0.blackClock)
        }
    }

    var resultSummary: ResultSummary { ResultSummary(outcome: outcome, termination: termination) }

    var resultText: String {
        switch outcome {
        case .win(.white): return "1–0"
        case .win(.black): return "0–1"
        case .draw: return "½–½"
        case .ongoing: return "*"
        }
    }
}

extension ArchivedGame {
    @MainActor
    init(from game: ChessGame, whiteName: String, blackName: String, id: UUID = UUID(), date: Date = Date()) {
        self.id = id
        self.date = date
        self.whiteName = whiteName
        self.blackName = blackName
        self.humanColor = game.humanColor
        self.opponentLabel = game.opponent.displayName
        self.timeControl = game.timeControl
        self.outcome = game.outcome
        self.termination = game.termination ?? .checkmate
        self.startFEN = game.history.first?.fenBefore ?? Position.standard.fen
        self.moves = game.history.map {
            Archived(ply: $0.ply, color: $0.color, san: $0.san, uci: $0.uci,
                     fenBefore: $0.fenBefore, fenAfter: $0.fenAfter,
                     whiteClock: $0.whiteClock, blackClock: $0.blackClock)
        }
    }
}

import Foundation
import ChessKit

struct ArchivedGame: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let sourceId: String?      // server game id for online games; nil for local games (used to de-dupe)
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
        case .draw: return "Draw"
        case .ongoing: return "—"
        case let .win(side):
            // Relative to the player when there is one; pass & play has no "you", so name the winner.
            if let me = humanColor { return side == me ? "Won" : "Lost" }
            return side == .white ? "White won" : "Black won"
        }
    }
}

extension ArchivedGame {
    @MainActor
    init(from game: ChessGame, whiteName: String, blackName: String,
         result: ResultSummary? = nil, sourceId: String? = nil,
         id: UUID = UUID(), date: Date = Date()) {
        self.id = id
        self.date = date
        self.sourceId = sourceId
        self.whiteName = whiteName
        self.blackName = blackName
        self.humanColor = game.humanColor
        self.opponentLabel = game.opponent.displayName
        self.timeControl = game.timeControl
        // Online games end server-side (resignation/timeout) so the local board's outcome can lag;
        // prefer the authoritative result when one is supplied.
        self.outcome = result?.outcome ?? game.outcome
        self.termination = result?.termination ?? game.termination ?? .checkmate
        self.startFEN = game.history.first?.fenBefore ?? Position.standard.fen
        self.moves = game.history.map {
            Archived(ply: $0.ply, color: $0.color, san: $0.san, uci: $0.uci,
                     fenBefore: $0.fenBefore, fenAfter: $0.fenAfter,
                     whiteClock: $0.whiteClock, blackClock: $0.blackClock)
        }
    }
}

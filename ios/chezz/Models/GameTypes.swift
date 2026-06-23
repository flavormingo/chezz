import Foundation
import ChessKit

typealias Side = Piece.Color

extension Side {
    var fullName: String { self == .white ? "White" : "Black" }
}

enum GameOutcome: Equatable, Codable, Hashable {
    case ongoing
    case win(Side)
    case draw

    var isOver: Bool { self != .ongoing }
    var winner: Side? { if case let .win(s) = self { return s }; return nil }

    var pgnResult: String {
        switch self {
        case .ongoing: return "*"
        case .win(.white): return "1-0"
        case .win(.black): return "0-1"
        case .draw: return "1/2-1/2"
        }
    }
}

enum Termination: String, Codable, Hashable {
    case checkmate, resignation, timeout, stalemate
    case agreement, insufficientMaterial, fiftyMove, repetition, abandoned

    var label: String {
        switch self {
        case .checkmate: return "Checkmate"
        case .resignation: return "Resignation"
        case .timeout: return "Time out"
        case .stalemate: return "Stalemate"
        case .agreement: return "Draw agreed"
        case .insufficientMaterial: return "Insufficient material"
        case .fiftyMove: return "Fifty-move rule"
        case .repetition: return "Repetition"
        case .abandoned: return "Abandoned"
        }
    }
}

enum OpponentKind: Hashable {
    case computer(AIDifficulty)
    case localHuman
    case online(opponentId: String, opponentName: String)

    var isComputer: Bool { if case .computer = self { return true }; return false }
    var isOnline: Bool { if case .online = self { return true }; return false }

    var displayName: String {
        switch self {
        case let .computer(d): return d.name
        case .localHuman: return "Pass & Play"
        case let .online(_, name): return name
        }
    }
}

struct ResultSummary: Equatable {
    var outcome: GameOutcome
    var termination: Termination

    var headline: String {
        switch outcome {
        case .win(.white): return "White won"
        case .win(.black): return "Black won"
        case .draw: return "Draw"
        case .ongoing: return ""
        }
    }
    var subtitle: String { "by \(termination.label.lowercased())" }
}

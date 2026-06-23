import Foundation

// Below Stockfish's 1320 Elo floor, beginner tiers use Skill Level + a depth/movetime cap; 1320+ uses UCI_LimitStrength + UCI_Elo.
struct AIDifficulty: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var blurb: String
    var approxElo: Int
    var limitStrength: Bool
    var uciElo: Int?
    var skillLevel: Int
    var moveTimeMs: Int
    var depth: Int?

    static let beginner = AIDifficulty(
        id: "beginner", name: "Beginner", blurb: "Just learning the moves",
        approxElo: 800, limitStrength: false, uciElo: nil, skillLevel: 0, moveTimeMs: 50, depth: 1)
    static let easy = AIDifficulty(
        id: "easy", name: "Easy", blurb: "Casual, makes mistakes",
        approxElo: 1100, limitStrength: false, uciElo: nil, skillLevel: 3, moveTimeMs: 150, depth: 4)
    static let casual = AIDifficulty(
        id: "casual", name: "Casual", blurb: "Improving club player",
        approxElo: 1320, limitStrength: true, uciElo: 1320, skillLevel: 20, moveTimeMs: 300, depth: nil)
    static let intermediate = AIDifficulty(
        id: "intermediate", name: "Intermediate", blurb: "Solid tactics",
        approxElo: 1600, limitStrength: true, uciElo: 1600, skillLevel: 20, moveTimeMs: 500, depth: nil)
    static let strong = AIDifficulty(
        id: "strong", name: "Strong", blurb: "Tough opponent",
        approxElo: 2000, limitStrength: true, uciElo: 2000, skillLevel: 20, moveTimeMs: 800, depth: nil)
    static let expert = AIDifficulty(
        id: "expert", name: "Expert", blurb: "Punishes errors",
        approxElo: 2400, limitStrength: true, uciElo: 2400, skillLevel: 20, moveTimeMs: 1000, depth: nil)
    static let master = AIDifficulty(
        id: "master", name: "Master", blurb: "Titled-player strength",
        approxElo: 2800, limitStrength: true, uciElo: 2800, skillLevel: 20, moveTimeMs: 1500, depth: nil)
    static let maximum = AIDifficulty(
        id: "maximum", name: "Maximum", blurb: "Full engine strength",
        approxElo: 3190, limitStrength: false, uciElo: nil, skillLevel: 20, moveTimeMs: 2000, depth: nil)

    static let all: [AIDifficulty] = [.beginner, .easy, .casual, .intermediate, .strong, .expert, .master, .maximum]
    static let `default` = AIDifficulty.casual

    static func named(_ id: String) -> AIDifficulty { all.first { $0.id == id } ?? .default }
}

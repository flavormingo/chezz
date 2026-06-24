import Foundation

// Beginner/Easy/Casual play in Skill Level mode with a shallow depth cap (genuinely weak, they blunder),
// since Stockfish's UCI_Elo floor of 1320 is too strong for newer players. Intermediate and up use
// UCI_LimitStrength + UCI_Elo (1500+); Maximum is full strength.
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

    // Humanizing pre-move delay (ms): the engine often replies almost instantly, so we pad the move
    // up to this floor. Weaker bots "deliberate" much longer than stronger ones; scaled smoothly from
    // ~4s at the bottom to ~0.6s at full strength off approxElo (the search dominates at the top).
    var thinkMs: Int {
        let lo = 600.0, hi = 3190.0, slow = 4000.0, fast = 600.0
        let t = min(1, max(0, (Double(approxElo) - lo) / (hi - lo)))
        return Int(slow - t * (slow - fast))
    }

    static let beginner = AIDifficulty(
        id: "beginner", name: "Beginner", blurb: "Just learning the moves",
        approxElo: 600, limitStrength: false, uciElo: nil, skillLevel: 0, moveTimeMs: 100, depth: 1)
    static let easy = AIDifficulty(
        id: "easy", name: "Easy", blurb: "Makes plenty of mistakes",
        approxElo: 900, limitStrength: false, uciElo: nil, skillLevel: 2, moveTimeMs: 150, depth: 2)
    static let casual = AIDifficulty(
        id: "casual", name: "Casual", blurb: "Still learning the basics",
        approxElo: 1200, limitStrength: false, uciElo: nil, skillLevel: 5, moveTimeMs: 300, depth: 4)
    static let intermediate = AIDifficulty(
        id: "intermediate", name: "Intermediate", blurb: "Solid club player",
        approxElo: 1500, limitStrength: true, uciElo: 1500, skillLevel: 20, moveTimeMs: 500, depth: nil)
    static let strong = AIDifficulty(
        id: "strong", name: "Strong", blurb: "Tough opponent",
        approxElo: 1900, limitStrength: true, uciElo: 1900, skillLevel: 20, moveTimeMs: 800, depth: nil)
    static let expert = AIDifficulty(
        id: "expert", name: "Expert", blurb: "Punishes errors",
        approxElo: 2300, limitStrength: true, uciElo: 2300, skillLevel: 20, moveTimeMs: 1000, depth: nil)
    static let master = AIDifficulty(
        id: "master", name: "Master", blurb: "Titled-player strength",
        approxElo: 2700, limitStrength: true, uciElo: 2700, skillLevel: 20, moveTimeMs: 1500, depth: nil)
    static let maximum = AIDifficulty(
        id: "maximum", name: "Maximum", blurb: "Full engine strength",
        approxElo: 3190, limitStrength: false, uciElo: nil, skillLevel: 20, moveTimeMs: 2000, depth: nil)

    static let all: [AIDifficulty] = [.beginner, .easy, .casual, .intermediate, .strong, .expert, .master, .maximum]
    static let `default` = AIDifficulty.casual

    static func named(_ id: String) -> AIDifficulty { all.first { $0.id == id } ?? .default }
}

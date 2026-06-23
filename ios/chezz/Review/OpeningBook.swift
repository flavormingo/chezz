import Foundation

// Keyed by leading SAN (exactly as ChessKit emits it); detect() returns the deepest matching line. Not exhaustive.
enum OpeningBook {
    static let lines: [(moves: [String], name: String)] = [
        (["e4"], "King's Pawn Opening"),
        (["e4", "e5"], "Open Game"),
        (["e4", "e5", "Nf3"], "King's Knight Opening"),
        (["e4", "e5", "Nf3", "Nc6"], "Open Game"),
        (["e4", "e5", "Nf3", "Nc6", "Bb5"], "Ruy López"),
        (["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"], "Ruy López, Morphy Defense"),
        (["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6"], "Ruy López, Closed"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4"], "Italian Game"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"], "Giuoco Piano"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6"], "Two Knights Defense"),
        (["e4", "e5", "Nf3", "Nc6", "d4"], "Scotch Game"),
        (["e4", "e5", "Nf3", "Nf6"], "Petrov's Defense"),
        (["e4", "e5", "Nf3", "Nc6", "Nc3"], "Three Knights"),
        (["e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6"], "Four Knights Game"),
        (["e4", "e5", "f4"], "King's Gambit"),
        (["e4", "e5", "Bc4"], "Bishop's Opening"),
        (["e4", "e5", "Nc3"], "Vienna Game"),
        (["e4", "c5"], "Sicilian Defense"),
        (["e4", "c5", "Nf3"], "Sicilian Defense"),
        (["e4", "c5", "Nf3", "d6"], "Sicilian, Najdorf-bound"),
        (["e4", "c5", "Nf3", "Nc6"], "Sicilian, Old Sicilian"),
        (["e4", "c5", "Nf3", "e6"], "Sicilian, French Variation"),
        (["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6"], "Sicilian, Najdorf"),
        (["e4", "c5", "c3"], "Sicilian, Alapin"),
        (["e4", "c5", "Nc3"], "Sicilian, Closed"),
        (["e4", "e6"], "French Defense"),
        (["e4", "e6", "d4", "d5"], "French Defense"),
        (["e4", "e6", "d4", "d5", "Nc3"], "French, Paulsen"),
        (["e4", "e6", "d4", "d5", "e5"], "French, Advance"),
        (["e4", "c6"], "Caro-Kann Defense"),
        (["e4", "c6", "d4", "d5"], "Caro-Kann Defense"),
        (["e4", "c6", "d4", "d5", "Nc3"], "Caro-Kann, Classical-bound"),
        (["e4", "d5"], "Scandinavian Defense"),
        (["e4", "Nf6"], "Alekhine's Defense"),
        (["e4", "d6"], "Pirc Defense"),
        (["e4", "g6"], "Modern Defense"),
        (["d4"], "Queen's Pawn Opening"),
        (["d4", "d5"], "Closed Game"),
        (["d4", "d5", "c4"], "Queen's Gambit"),
        (["d4", "d5", "c4", "e6"], "Queen's Gambit Declined"),
        (["d4", "d5", "c4", "c6"], "Slav Defense"),
        (["d4", "d5", "c4", "dxc4"], "Queen's Gambit Accepted"),
        (["d4", "Nf6"], "Indian Defense"),
        (["d4", "Nf6", "c4"], "Indian Game"),
        (["d4", "Nf6", "c4", "g6"], "King's Indian / Grünfeld"),
        (["d4", "Nf6", "c4", "g6", "Nc3", "Bg7"], "King's Indian Defense"),
        (["d4", "Nf6", "c4", "g6", "Nc3", "d5"], "Grünfeld Defense"),
        (["d4", "Nf6", "c4", "e6"], "Indian, Nimzo/QID-bound"),
        (["d4", "Nf6", "c4", "e6", "Nc3", "Bb4"], "Nimzo-Indian Defense"),
        (["d4", "Nf6", "c4", "e6", "Nf3", "b6"], "Queen's Indian Defense"),
        (["d4", "Nf6", "Nf3"], "Indian, London-bound"),
        (["d4", "d5", "Nf3"], "Queen's Pawn Game"),
        (["d4", "f5"], "Dutch Defense"),
        (["c4"], "English Opening"),
        (["c4", "e5"], "English, Reversed Sicilian"),
        (["c4", "c5"], "English, Symmetrical"),
        (["c4", "Nf6"], "English, Anglo-Indian"),
        (["Nf3"], "Réti / King's Indian Attack"),
        (["Nf3", "d5", "c4"], "Réti Opening"),
        (["Nf3", "Nf6"], "Réti Opening"),
        (["g3"], "Hungarian / King's Fianchetto"),
        (["b3"], "Nimzo-Larsen Attack"),
        (["f4"], "Bird's Opening"),
    ]

    static func detect(sans: [String]) -> (name: String, bookPlies: Int)? {
        var best: (name: String, bookPlies: Int)?
        for entry in lines where sans.count >= entry.moves.count {
            if Array(sans.prefix(entry.moves.count)) == entry.moves {
                if best == nil || entry.moves.count > best!.bookPlies {
                    best = (entry.name, entry.moves.count)
                }
            }
        }
        return best
    }
}

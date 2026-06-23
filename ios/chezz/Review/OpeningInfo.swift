import Foundation

// Keys are matched as substrings, so list more-specific names first (e.g. "Queen's Gambit Declined" before "Queen's Gambit").
enum OpeningInfo {
    static let blurbs: [(key: String, text: String)] = [
        ("Ruy López", "One of the oldest and most trusted openings. White's bishop attacks the knight defending Black's centre, leading to rich, strategic play."),
        ("Italian Game", "White develops naturally and points the bishop at Black's vulnerable f7 square, aiming for quick development and a strong centre."),
        ("Giuoco Piano", "A calm, classical line of the Italian Game, both sides develop quietly and fight for the centre."),
        ("Two Knights", "An aggressive reply in the Italian where Black invites sharp, tactical play instead of quiet development."),
        ("Scotch Game", "White strikes in the centre early with d4, opening the position quickly for active piece play."),
        ("Petrov", "Black mirrors White's setup and counter-attacks immediately, a solid, drawish defence."),
        ("Four Knights", "Both sides develop all their knights early. Symmetrical, sensible and easy to learn."),
        ("Three Knights", "An older, flexible development of the knights in the Open Game."),
        ("King's Gambit", "A bold, romantic gambit: White sacrifices a pawn for fast development and an attack."),
        ("Vienna Game", "White develops the queenside knight first, keeping options open for a later f4 push."),
        ("Bishop's Opening", "White develops the bishop toward f7 right away, often transposing into Italian-style positions."),
        ("Scandinavian", "Black immediately challenges White's e4 pawn with ...d5. Direct, easy to learn and Black often develops the queen early."),
        ("Alekhine", "Black provokes White's pawns forward with the knight, planning to attack that big centre later."),
        ("Pirc", "Black gives White a big pawn centre on purpose, then fianchettoes the bishop and strikes back."),
        ("Modern Defense", "Similar to the Pirc, Black fianchettoes early and lets White build a centre to attack."),
        ("Sicilian", "The most popular and combative answer to 1.e4. Black fights for the centre asymmetrically and plays for a win."),
        ("French", "Black builds a solid pawn chain and aims for a later counter-strike in the centre. Sturdy but a little cramped."),
        ("Caro-Kann", "A rock-solid defence: Black supports a central break with ...c6 and gets a sound, durable position."),
        ("Queen's Gambit Declined", "Black declines the offered pawn and builds a solid, classical centre. A mainstay of top-level chess."),
        ("Queen's Gambit Accepted", "Black grabs the c4 pawn, accepting a lead in White's development in return for the extra pawn (usually given back)."),
        ("Queen's Gambit", "White offers a side pawn to pull Black's centre pawn away and dominate the centre."),
        ("Slav", "Black supports the d5 pawn with ...c6 instead of blocking the bishop. Very solid and popular."),
        ("King's Indian", "Black lets White build a huge centre, then fianchettoes and launches a kingside pawn storm. Sharp and double-edged."),
        ("Grünfeld", "Black invites a big White centre, then chips away at it with pieces and pawn breaks."),
        ("Nimzo-Indian", "Black pins White's knight to fight for the centre with pieces rather than pawns. Highly respected."),
        ("Queen's Indian", "Black fianchettoes the bishop to control the long diagonal and the e4 square. Solid and flexible."),
        ("Dutch", "Black stakes a claim on the kingside with ...f5, aiming for attacking chances."),
        ("Indian", "Black answers d4 with a knight and a flexible setup rather than an early ...d5."),
        ("English", "White starts on the flank with c4, controlling the centre from the side. Flexible and strategic."),
        ("Réti", "White develops the knight and fianchettoes, inviting Black to over-extend in the centre."),
        ("Nimzo-Larsen", "White fianchettoes the queenside bishop early, an offbeat, hypermodern setup."),
        ("Bird", "White opens with f4, grabbing kingside space in a reversed-Dutch setup."),
        ("King's Knight", "A natural first developing move, attacking Black's e5 pawn and preparing to castle."),
        ("Open Game", "Both sides push their king's pawns two squares, leading to open, piece-active positions."),
        ("Closed Game", "Both sides push their queen's pawns, usually leading to slower, more strategic play."),
        ("King's Pawn", "White opens with 1.e4, the most popular first move, freeing the bishop and queen and grabbing the centre."),
        ("Queen's Pawn", "White opens with 1.d4, a solid way to claim the centre and steer toward strategic positions."),
    ]

    static func blurb(for name: String) -> String {
        for entry in blurbs where name.localizedCaseInsensitiveContains(entry.key) { return entry.text }
        return "A recognized opening. These first moves follow established theory, known sequences that develop the pieces and fight for control of the centre."
    }
}

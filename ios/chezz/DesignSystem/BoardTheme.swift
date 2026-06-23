import SwiftUI

struct BoardTheme: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var lightHex: String
    var darkHex: String

    var light: Color { Color(hex: lightHex) }
    var dark: Color  { Color(hex: darkHex) }

    func color(isLight: Bool) -> Color { isLight ? light : dark }

    static let midnight = BoardTheme(id: "midnight", name: "Midnight", lightHex: "#4E596E", darkHex: "#374050")
    static let slate    = BoardTheme(id: "slate",    name: "Slate",    lightHex: "#7B8696", darkHex: "#454F5E")
    // id stays "green" for backwards-compatible persistence; display name is "Forest".
    static let green    = BoardTheme(id: "green",    name: "Forest",   lightHex: "#CCCCB4", darkHex: "#5E884B")
    static let wood     = BoardTheme(id: "wood",     name: "Wood",     lightHex: "#CABA9B", darkHex: "#9B7455")
    static let ocean    = BoardTheme(id: "ocean",    name: "Ocean",    lightHex: "#BCC5CA", darkHex: "#5E7D95")

    // Alphabetical by display name.
    static let all: [BoardTheme] = [.green, .midnight, .ocean, .slate, .wood]

    static func named(_ id: String) -> BoardTheme { all.first { $0.id == id } ?? .wood }
}

enum BoardStyle {
    static var lastMove: Color  { Palette.mint.opacity(0.28) }
    static var selected: Color  { Palette.mint.opacity(0.45) }
    static var legalDot: Color  { Palette.mint.opacity(0.9) }
    static var legalRing: Color { Palette.mint.opacity(0.9) }
    static let checkGlow  = Palette.danger
    static let coordinate = Color.white.opacity(0.55)
    static let premove    = Palette.gold.opacity(0.35)
}

import SwiftUI
import Observation

struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let accentHex: String
    let onAccentHex: String

    var accent: Color { Color(hex: accentHex) }
    var onAccent: Color { Color(hex: onAccentHex) }

    static let baghdad    = AppTheme(id: "baghdad",      name: "Baghdad",      accentHex: "#34E5A1", onAccentHex: "#06231A")
    static let beijing    = AppTheme(id: "beijing",      name: "Beijing",      accentHex: "#B98BFF", onAccentHex: "#1E0E3A")
    static let kannauj    = AppTheme(id: "kannauj",      name: "Kannauj",      accentHex: "#D9A066", onAccentHex: "#2B1A0A")
    // A true black accent would vanish on the dark UI, so London uses a crisp platinum.
    static let london     = AppTheme(id: "london",       name: "London",       accentHex: "#CBD3DF", onAccentHex: "#0E1116")
    static let moscow     = AppTheme(id: "moscow",       name: "Moscow",       accentHex: "#5AA8FF", onAccentHex: "#04162E")
    static let saintLouis = AppTheme(id: "saint-louis",  name: "Saint Louis",  accentHex: "#FF6B6B", onAccentHex: "#2E0A0A")
    static let seville    = AppTheme(id: "seville",      name: "Seville",      accentHex: "#FFD43B", onAccentHex: "#2E2407")
    static let wijkAanZee = AppTheme(id: "wijk-aan-zee", name: "Wijk aan Zee", accentHex: "#FF9F4A", onAccentHex: "#2E1606")

    // Alphabetical by name (the order shown in Settings).
    static let all: [AppTheme] = [
        .baghdad, .beijing, .kannauj, .london, .moscow, .saintLouis, .seville, .wijkAanZee,
    ]

    static let `default`: AppTheme = .baghdad

    static func named(_ id: String) -> AppTheme { all.first { $0.id == id } ?? .default }
}

// @Observable so reading a themed color via Palette in a view body registers a dependency and recolors on theme change.
@Observable
final class ThemeHolder {
    static let shared = ThemeHolder()
    var theme: AppTheme = .default
    private init() {}
}

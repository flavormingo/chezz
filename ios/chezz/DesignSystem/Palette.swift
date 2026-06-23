import SwiftUI

enum Palette {
    static let canvas      = Color(hex: "#0E1116")
    static let surface     = Color(hex: "#161B22")
    static let surface2    = Color(hex: "#1C232E")
    static let elevated    = Color(hex: "#222C39")
    static let hairline    = Color(hex: "#2A323D")

    static let textPrimary   = Color(hex: "#E6EAF0")
    static let textSecondary = Color(hex: "#8B95A7")
    static let textTertiary  = Color(hex: "#5C6677")
    static var onAccent: Color { ThemeHolder.shared.theme.onAccent }

    // Computed so view bodies track the active theme and recolor live; "mint" keeps its name (referenced app-wide).
    static var mint: Color        { ThemeHolder.shared.theme.accent }
    static var mintSoft: Color    { ThemeHolder.shared.theme.accent.opacity(0.16) }
    static let gold        = Color(hex: "#FFC857")

    static let danger   = Color(hex: "#E5484D")
    static let warning  = Color(hex: "#F2994A")
    static let positive = Color(hex: "#34E5A1")

    static let evalWhite = Color(hex: "#EDEFF3")
    static let evalBlack = Color(hex: "#0B0E12")
}

enum ClassificationStyle {
    static func color(_ c: MoveClassification) -> Color {
        switch c {
        case .brilliant:  return Color(hex: "#FFC857")
        case .great:      return Color(hex: "#5B9DFF")
        case .best:       return Color(hex: "#34E5A1")
        case .excellent:  return Color(hex: "#5FD08A")
        case .good:       return Color(hex: "#9BBF8A")
        case .book:       return Color(hex: "#C9A66B")
        case .inaccuracy: return Color(hex: "#E6C84B")
        case .mistake:    return Color(hex: "#F2994A")
        case .miss:       return Color(hex: "#EB5C9C")
        case .blunder:    return Color(hex: "#E5484D")
        }
    }

    static func symbol(_ c: MoveClassification) -> String {
        switch c {
        case .brilliant:  return "!!"
        case .great:      return "!"
        case .best:       return "★"
        case .excellent:  return "✓"
        case .good:       return "✓"
        case .book:       return "📖"
        case .inaccuracy: return "?!"
        case .mistake:    return "?"
        case .miss:       return "✕"
        case .blunder:    return "??"
        }
    }
}

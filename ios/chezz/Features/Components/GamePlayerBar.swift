import SwiftUI
import ChessKit

struct ClockView: View {
    let seconds: TimeInterval
    var isActive: Bool
    var isLow: Bool

    var body: some View {
        Text(formatted)
            .font(.chezzClock(22))
            .foregroundStyle(isActive ? Palette.canvas : (isLow ? Palette.danger : Palette.textPrimary))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(isActive ? .clear : Palette.hairline, lineWidth: 1))
    }

    private var background: Color {
        if isActive { return isLow ? Palette.danger : Palette.mint }
        return Palette.surface2
    }

    private var formatted: String {
        let t = max(0, seconds)
        let total = Int(t)
        let m = total / 60, s = total % 60
        if t < 20 {
            let tenths = Int((t - floor(t)) * 10)
            return String(format: "%d:%02d.%d", m, s, tenths)
        }
        return String(format: "%d:%02d", m, s)
    }
}

enum Captured {
    static let initialCounts: [Piece.Kind: Int] = [.pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1]
    static let order: [Piece.Kind] = [.queen, .rook, .bishop, .knight, .pawn]

    static func capturedPieces(of color: Side, pieces: [Square: Piece]) -> [Piece.Kind] {
        var present: [Piece.Kind: Int] = [:]
        for p in pieces.values where p.color == color { present[p.kind, default: 0] += 1 }
        var out: [Piece.Kind] = []
        for kind in order {
            let missing = (initialCounts[kind] ?? 0) - (present[kind] ?? 0)
            if missing > 0 { out.append(contentsOf: Array(repeating: kind, count: missing)) }
        }
        return out
    }

    static func advantage(for side: Side, pieces: [Square: Piece]) -> Int {
        var score = 0
        for p in pieces.values {
            let v = Material.value[p.kind] ?? 0
            score += (p.color == side) ? v : -v
        }
        return score
    }
}

struct CapturedTray: View {
    let capturedColor: Side
    let kinds: [Piece.Kind]
    let advantage: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                PieceGlyphLabel(kind: kind, color: capturedColor, size: 14)
            }
            if advantage > 0 {
                Text("+\(advantage)")
                    .font(.chezzCaption2)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.leading, 2)
            }
        }
        .frame(height: 16)
    }
}

struct GamePlayerBar: View {
    let name: String
    let rating: Int?
    let colorHex: String
    let isBot: Bool
    let side: Side
    let pieces: [Square: Piece]
    let clockSeconds: TimeInterval?
    let clockActive: Bool
    let clockLow: Bool
    let toMove: Bool
    var imageURL: URL? = nil

    var body: some View {
        let captured = Captured.capturedPieces(of: side.opposite, pieces: pieces)
        let advantage = Captured.advantage(for: side, pieces: pieces)
        return HStack(spacing: Spacing.sm) {
            Avatar(name: name, colorHex: colorHex, size: 42, isBot: isBot, imageURL: imageURL)
                .overlay(alignment: .bottomTrailing) {
                    if toMove {
                        Circle().fill(Palette.mint).frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(Palette.canvas, lineWidth: 2))
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name).font(.chezzHeadline).foregroundStyle(Palette.textPrimary).lineLimit(1)
                    if let rating { Text("\(rating)").font(.chezzCaption).foregroundStyle(Palette.textSecondary) }
                }
                if !captured.isEmpty || advantage > 0 {
                    CapturedTray(capturedColor: side.opposite, kinds: captured, advantage: advantage)
                }
            }
            Spacer(minLength: Spacing.xs)
            if let clockSeconds {
                ClockView(seconds: clockSeconds, isActive: clockActive, isLow: clockLow)
            }
        }
    }
}

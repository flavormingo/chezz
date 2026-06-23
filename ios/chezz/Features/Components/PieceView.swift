import SwiftUI
import ChessKit

struct PieceView: View {
    let piece: Piece
    var size: CGFloat

    var body: some View {
        Image(PieceArt.assetName(kind: piece.kind, color: piece.color))
            .resizable().renderingMode(.template).scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(piece.color == .white ? Color(hex: "#F4F7FC") : Color(hex: "#0E141B"))
            .shadow(color: .black.opacity(0.28), radius: size * 0.02, x: 0, y: size * 0.02)
            .allowsHitTesting(false)
    }
}

enum PieceArt {
    static func assetName(kind: Piece.Kind, color _: Side) -> String {
        // Both colors use the same filled glyph (stored in the "-black" imageset); color comes from the caller's tint.
        "piece-\(name(kind))-black"
    }
    private static func name(_ kind: Piece.Kind) -> String {
        switch kind {
        case .king:   return "king"
        case .queen:  return "queen"
        case .rook:   return "rook"
        case .bishop: return "bishop"
        case .knight: return "knight"
        case .pawn:   return "pawn"
        }
    }
}

struct PieceGlyphLabel: View {
    let kind: Piece.Kind
    let color: Side
    var size: CGFloat = 16
    var body: some View {
        Image(PieceArt.assetName(kind: kind, color: color))
            .resizable().renderingMode(.template).scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color == .white ? Palette.textPrimary : Color(hex: "#6B7280"))
    }
}

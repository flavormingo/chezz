import SwiftUI
import ChessKit

struct PromotionOverlay: View {
    let color: Side
    let onSelect: (Piece.Kind) -> Void
    let onCancel: () -> Void

    private let kinds: [Piece.Kind] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(spacing: Spacing.md) {
                Text("Promote to")
                    .font(.chezzHeadline)
                    .foregroundStyle(Palette.textPrimary)
                HStack(spacing: Spacing.sm) {
                    ForEach(kinds, id: \.self) { kind in
                        Button { onSelect(kind) } label: {
                            PieceView(piece: Piece(kind, color: color, square: .e4), size: 52)
                                .frame(width: 64, height: 64)
                                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.lg)
            .chezzCard()
            .padding(.horizontal, Spacing.xl)
        }
        .transition(.opacity)
    }
}

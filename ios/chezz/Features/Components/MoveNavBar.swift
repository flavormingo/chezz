import SwiftUI

struct MoveNavBar: View {
    let game: ChessGame

    var body: some View {
        // Always shown (even pre-game) so the controls don't pop in mid-game and shift the layout.
        HStack(spacing: Spacing.xs) {
            navButton("chevron.left.2", enabled: game.canStepBack) { game.browseFirst() }
            navButton("chevron.left", enabled: game.canStepBack) { game.browseBack() }

            Text(game.browseLabel)
                .font(.chezzCaption.monospacedDigit())
                .foregroundStyle(game.isBrowsing ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            navButton("chevron.right", enabled: game.canStepForward) { game.browseForward() }
            navButton("chevron.right.2", enabled: game.canStepForward) { game.browseLive() }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func navButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { action() } } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.textTertiary)
                .frame(width: 46, height: 34)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

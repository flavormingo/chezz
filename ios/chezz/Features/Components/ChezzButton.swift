import SwiftUI

struct ChezzPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.mint
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.chezzHeadline)
            .foregroundStyle(enabled ? Palette.onAccent : Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background((enabled ? tint : Palette.surface2).opacity(configuration.isPressed ? 0.82 : 1),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ChezzSecondaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.mint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.chezzHeadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Palette.surface2.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GameActionButton: View {
    let icon: String
    let label: String
    var tint: Color = Palette.textSecondary
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(label).font(.chezzCaption)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

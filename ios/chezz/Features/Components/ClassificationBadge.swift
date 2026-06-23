import SwiftUI

struct ClassificationBadge: View {
    let classification: MoveClassification
    var size: CGFloat = 22

    var body: some View {
        let color = ClassificationStyle.color(classification)
        Group {
            if classification == .book {
                Image(systemName: "book.fill")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(Palette.canvas)
            } else {
                Text(ClassificationStyle.symbol(classification))
                    .font(.system(size: size * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .background(color, in: Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
    }

    private var textColor: Color {
        switch classification {
        case .blunder, .mistake, .miss: return .white
        default: return Palette.canvas
        }
    }
}

struct ClassificationLegendRow: View {
    let classification: MoveClassification
    let count: Int
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ClassificationBadge(classification: classification, size: 22)
            Text(classification.label)
                .font(.chezzCallout)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.chezzCallout.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

import SwiftUI

// Compact secondary line for user rows: "🔥 {streak} · {rating}" when the streak is active, just the
// rating otherwise. Replaces the redundant "@username" line (the name is already shown above it).
struct StreakRatingLabel: View {
    let streak: Int
    let rating: Int

    var body: some View {
        HStack(spacing: 3) {
            if streak > 0 {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(streak) · \(rating)")
            } else {
                Text("\(rating)")
            }
        }
        .font(.chezzCaption)
        .foregroundStyle(Palette.textSecondary)
    }
}

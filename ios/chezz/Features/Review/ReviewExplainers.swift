import SwiftUI

struct OpeningInfoView: View {
    let name: String
    let moves: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "book.fill").font(.title2).foregroundStyle(Palette.gold)
                        Text(name).font(.chezzTitle2).foregroundStyle(Palette.textPrimary)
                    }
                    if !moves.isEmpty {
                        Text(movesLine).font(.chezzCallout.monospacedDigit())
                            .foregroundStyle(Palette.mint)
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                    }
                    Text(OpeningInfo.blurb(for: name))
                        .font(.chezzBody).foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("“Book” moves like these aren't scored, they're established theory that strong players have refined over decades.")
                        .font(.chezzCaption).foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.lg)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Opening").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(Palette.mint) } }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var movesLine: String {
        var s = ""
        for (i, san) in moves.enumerated() {
            if i % 2 == 0 { s += "\(i / 2 + 1). " }
            s += san + " "
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

struct ClassificationGlossaryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Every move gets a rating based on how it compares to the engine's top choice. Here's what each one means:")
                        .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(MoveClassification.allCases, id: \.self) { c in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            ClassificationBadge(classification: c, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.label).font(.chezzHeadline)
                                    .foregroundStyle(ClassificationStyle.color(c))
                                Text(c.explanation).font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accuracy").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                        Text("Your overall score out of 100 for how closely you matched the engine's best moves. Higher is better, even strong players rarely top 90.")
                            .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.lg)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Move ratings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(Palette.mint) } }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}

import SwiftUI

struct ChallengeSheet: View {
    let friend: UserProfile
    var onCreate: (TimeControl, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Double = 10
    @State private var increment = 0
    @State private var timed = true
    @State private var color = "random"
    @State private var busy = false
    @State private var error: String?

    private let colors = ["white", "random", "black"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    HStack(spacing: Spacing.sm) {
                        Avatar(name: friend.name, colorHex: friend.avatarColor, size: 44, imageURL: friend.imageURL.flatMap { URL(string: $0) })
                        VStack(alignment: .leading) {
                            Text(friend.name).font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                            Text("@\(friend.username)").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(Spacing.md).chezzCard()

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Text("Timed").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Toggle("", isOn: $timed).labelsHidden().tint(Palette.mint)
                        }
                        if timed {
                            HStack {
                                Text("Minutes per side").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                                Spacer()
                                Text("\(Int(minutes))").font(.chezzHeadline).foregroundStyle(Palette.mint)
                            }
                            Slider(value: $minutes, in: 1...60, step: 1).tint(Palette.mint)
                            Stepper("Increment: \(increment)s", value: $increment, in: 0...30)
                                .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                        } else {
                            Text("Turn-based, play over hours or days.").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .padding(Spacing.md).chezzCard()

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("You play as").font(.chezzCaption).foregroundStyle(Palette.textTertiary).textCase(.uppercase)
                        HStack(spacing: Spacing.sm) {
                            ForEach(colors, id: \.self) { c in
                                Button { color = c } label: {
                                    Text(c.capitalized).font(.chezzCallout)
                                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                                        .foregroundStyle(color == c ? Palette.onAccent : Palette.textPrimary)
                                        .background(color == c ? Palette.mint : Palette.surface2,
                                                    in: RoundedRectangle(cornerRadius: Radius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(Spacing.md).chezzCard()

                    if let error { Text(error).font(.chezzCaption).foregroundStyle(Palette.danger) }
                }
                .padding(Spacing.md)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary) }
            }
            .safeAreaInset(edge: .bottom) {
                Button { Task { await create() } } label: {
                    if busy { ProgressView().tint(Palette.onAccent) } else { Text("Send challenge") }
                }
                .buttonStyle(ChezzPrimaryButtonStyle())
                .padding(Spacing.md).background(Palette.canvas)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func create() async {
        busy = true; error = nil
        let tc = timed ? TimeControl.minutes(Int(minutes), increment: increment) : .untimed
        let ok = await onCreate(tc, color)
        busy = false
        if ok { dismiss() } else { error = "Couldn't send the challenge." }
    }
}

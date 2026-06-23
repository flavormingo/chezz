import SwiftUI
import ChessKit

struct NewGameConfig {
    var opponent: OpponentKind
    var humanColor: Side?
    var timeControl: TimeControl
}

struct NewGameView: View {
    @Environment(\.dismiss) private var dismiss
    var defaultMinutes: Int
    var onStart: (NewGameConfig) -> Void
    var onPlayFriend: (() -> Void)?

    enum Mode: String, CaseIterable, Identifiable {
        case computer = "Computer", friend = "Friend", passPlay = "Pass & Play"
        var id: String { rawValue }
        var icon: String {
            switch self { case .computer: "cpu"; case .friend: "person.2.fill"; case .passPlay: "iphone" }
        }
    }
    enum ColorChoice: String, CaseIterable, Identifiable {
        case white, random, black
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    @State private var mode: Mode = .computer
    @State private var difficulty: AIDifficulty = .default
    @State private var colorChoice: ColorChoice = .random
    @State private var minutes: Double
    @State private var increment: Int = 0
    @State private var timed: Bool = true

    init(defaultMinutes: Int, onStart: @escaping (NewGameConfig) -> Void, onPlayFriend: (() -> Void)? = nil) {
        self.defaultMinutes = defaultMinutes
        self.onStart = onStart
        self.onPlayFriend = onPlayFriend
        _minutes = State(initialValue: Double(defaultMinutes))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    modePicker
                    if mode == .computer { computerOptions }
                    if mode != .friend { timeControlSection }
                    if mode == .friend { friendNote }
                }
                .padding(Spacing.md)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) { startBar }
            .toolbarBackground(Palette.surface, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var modePicker: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Mode.allCases) { m in
                Button { withAnimation(.easeOut(duration: 0.15)) { mode = m } } label: {
                    VStack(spacing: 6) {
                        Image(systemName: m.icon).font(.system(size: 20, weight: .semibold))
                        Text(m.rawValue).font(.chezzCaption)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                    .foregroundStyle(mode == m ? Palette.onAccent : Palette.textSecondary)
                    .background(mode == m ? Palette.mint : Palette.surface2,
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var computerOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("Difficulty")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(AIDifficulty.all) { d in
                        Button { difficulty = d } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.name).font(.chezzCallout).lineLimit(1).foregroundStyle(difficulty == d ? Palette.onAccent : Palette.textPrimary)
                                Text("~\(d.approxElo)").font(.chezzCaption2).lineLimit(1).foregroundStyle(difficulty == d ? Palette.onAccent.opacity(0.8) : Palette.textSecondary)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                            .frame(minWidth: 80, alignment: .leading)
                            .background(difficulty == d ? Palette.mint : Palette.surface2,
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(difficulty.blurb).font(.chezzCaption).foregroundStyle(Palette.textSecondary)

            sectionTitle("You play as")
            HStack(spacing: Spacing.sm) {
                ForEach(ColorChoice.allCases) { c in
                    Button { colorChoice = c } label: {
                        Text(c.label).font(.chezzCallout)
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                            .foregroundStyle(colorChoice == c ? Palette.onAccent : Palette.textPrimary)
                            .background(colorChoice == c ? Palette.mint : Palette.surface2,
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md).chezzCard()
    }

    private var timeControlSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                sectionTitle("Time control")
                Spacer()
                Toggle("", isOn: $timed).labelsHidden().tint(Palette.mint)
            }
            if timed {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(TimeControl.presets.filter { !$0.isUntimed }) { tc in
                            chip(tc.displayName, selected: isPreset(tc)) {
                                minutes = Double(tc.initialMinutes); increment = tc.incrementSeconds
                            }
                        }
                    }
                }
                VStack(spacing: Spacing.xs) {
                    HStack {
                        Text("Minutes per side").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("\(Int(minutes))").font(.chezzHeadline).foregroundStyle(Palette.mint)
                    }
                    Slider(value: $minutes, in: 1...60, step: 1).tint(Palette.mint)
                    Stepper("Increment: \(increment)s", value: $increment, in: 0...30, step: 1)
                        .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                }
            } else {
                Text("Turn-based, no clock. Play at your own pace.")
                    .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(Spacing.md).chezzCard()
    }

    private var friendNote: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "person.2.fill").font(.system(size: 28)).foregroundStyle(Palette.mint)
            Text("Challenge a friend").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            Text("Sign in to add friends and play online, timed or turn-based.")
                .font(.chezzSubhead).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            Button("Go to Friends") { onPlayFriend?(); dismiss() }
                .buttonStyle(ChezzSecondaryButtonStyle())
        }
        .padding(Spacing.lg).frame(maxWidth: .infinity).chezzCard()
    }

    private var startBar: some View {
        Group {
            if mode != .friend {
                Button { start() } label: { Text("Start Game") }
                    .buttonStyle(ChezzPrimaryButtonStyle())
                    .padding(Spacing.md)
                    .background(Palette.canvas)
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.chezzCaption).foregroundStyle(Palette.textTertiary).textCase(.uppercase)
    }

    private func chip(_ t: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.chezzCallout)
                .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                .foregroundStyle(selected ? Palette.onAccent : Palette.textPrimary)
                .background(selected ? Palette.mint : Palette.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func isPreset(_ tc: TimeControl) -> Bool {
        Int(minutes) == tc.initialMinutes && increment == tc.incrementSeconds
    }

    private func start() {
        let tc = timed ? TimeControl.minutes(Int(minutes), increment: increment) : .untimed
        let opponent: OpponentKind = mode == .computer ? .computer(difficulty) : .localHuman
        let human: Side?
        if mode == .computer {
            switch colorChoice {
            case .white: human = .white
            case .black: human = .black
            case .random: human = Bool.random() ? .white : .black
            }
        } else {
            human = nil
        }
        onStart(NewGameConfig(opponent: opponent, humanColor: human, timeControl: tc))
        dismiss()
    }
}

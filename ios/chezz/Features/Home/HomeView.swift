import SwiftUI
import ChessKit

struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(GameArchive.self) private var archive
    var onRequestFriends: () -> Void = {}

    @State private var showNewGame = false
    @State private var route: Route?
    @State private var recorded: Set<UUID> = []

    enum Route: Identifiable {
        case game(GameViewModel)
        case review(ReviewViewModel)
        var id: UUID { switch self { case let .game(v): v.id; case let .review(v): v.id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    hero
                    quickPlay
                    recentGames
                }
                .padding(Spacing.md)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.mint)
        .sheet(isPresented: $showNewGame) {
            NewGameView(defaultMinutes: settings.defaultMinutes,
                        onStart: { startGame($0) },
                        onPlayFriend: { onRequestFriends() })
                .presentationDetents([.large])
        }
        .fullScreenCover(item: $route) { route in cover(route) }
        .task { autoReviewIfRequested() }
    }

    private func autoReviewIfRequested() {
        #if DEBUG
        // UI-test hook (-chezz-autoreview): jump straight into a Game Review of a canned
        // Scandinavian game so the review explainers can be exercised without a live game.
        guard route == nil, ProcessInfo.processInfo.arguments.contains("-chezz-autoreview") else { return }
        let g = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        for uci in ["e2e4", "d7d5", "e4d5", "d8d5", "b1c3", "d5a5", "d2d4", "g8f6", "g1f3", "c7c6"] {
            _ = g.applyUCIMove(uci)
        }
        route = .review(ReviewViewModel(history: g.history, startFEN: Position.standard.fen,
                                        result: nil, whiteName: "White", blackName: "Black"))
        #endif
    }

    private var hero: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill").font(.system(size: 30)).foregroundStyle(Palette.gold)
            Text("Ready to play?").font(.chezzTitle).foregroundStyle(Palette.textPrimary)
            Text("Play a friend, the computer or pass and play.")
                .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
            Button { showNewGame = true } label: { Text("New Game") }
                .buttonStyle(ChezzPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .chezzCard()
    }

    private var quickPlay: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Quick play").font(.chezzCaption).foregroundStyle(Palette.textTertiary).textCase(.uppercase)
            quickCard(icon: "person.2.fill", title: "Play a Friend", subtitle: "Online, timed or turn-based", wide: true) {
                onRequestFriends()
            }
            quickCard(icon: "cpu", title: "Play a Robot", subtitle: "Challenge the computer", wide: true) {
                startGame(NewGameConfig(opponent: .computer(.default), humanColor: .white, timeControl: .rapid))
            }
            quickCard(icon: "iphone", title: "Pass and Play", subtitle: "Two players, one device", wide: true) {
                startGame(NewGameConfig(opponent: .localHuman, humanColor: nil, timeControl: .rapid))
            }
        }
    }

    private func quickCard(icon: String, title: String, subtitle: String, wide: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.mint)
                    .frame(width: 40, height: 40).background(Palette.mintSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                    Text(subtitle).font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                }
                if wide { Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.textTertiary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .chezzCard(fill: Palette.surface, radius: Radius.md)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick-" + title.replacingOccurrences(of: " ", with: ""))
    }

    private var recentGames: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Recent games").font(.chezzCaption).foregroundStyle(Palette.textTertiary).textCase(.uppercase)
            if archive.games.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(Palette.textTertiary)
                        .frame(width: 32, height: 32).background(Palette.surface2, in: Circle())
                    Text("Finished games show up here. Play one to the end, then tap it to review.")
                        .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
            } else {
                ForEach(archive.games.prefix(4)) { g in
                    Button { reviewArchived(g) } label: { recentRow(g) }.buttonStyle(.plain)
                }
                if archive.games.count > 4 {
                    NavigationLink { allGamesScreen } label: {
                        HStack {
                            Text("Show More").font(.chezzCallout).foregroundStyle(Palette.mint)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.textTertiary)
                        }
                        .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var allGamesScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(archive.games) { g in
                    Button { reviewArchived(g) } label: { recentRow(g) }.buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("All games")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recentRow(_ g: ArchivedGame) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: resultIcon(g)).foregroundStyle(resultColor(g))
                .frame(width: 32, height: 32).background(Palette.surface2, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(g.humanColor == nil ? "Pass and Play" : "\(g.whiteName) vs \(g.blackName)").font(.chezzCallout).foregroundStyle(Palette.textPrimary).lineLimit(1)
                Text("\(g.timeControl.displayName) · \(g.termination.label)").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Text(g.resultText).font(.chezzCallout.monospacedDigit()).foregroundStyle(Palette.textSecondary)
            Image(systemName: "sparkles").font(.caption).foregroundStyle(Palette.mint)
        }
        .padding(Spacing.sm)
        .chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func resultIcon(_ g: ArchivedGame) -> String {
        switch g.outcome { case .draw: "equal"; case .ongoing: "circle"; default: "flag.checkered" }
    }
    private func resultColor(_ g: ArchivedGame) -> Color {
        guard let human = g.humanColor else { return Palette.textSecondary }
        switch g.outcome {
        case .win(human): return Palette.mint
        case .draw: return Palette.textSecondary
        case .ongoing: return Palette.textSecondary
        default: return Palette.danger
        }
    }

    @ViewBuilder
    private func cover(_ route: Route) -> some View {
        switch route {
        case let .game(vm):
            // .id forces a fresh GameView (and its @State vm) when the route's model changes;
            // a cover already presented keeps the same view otherwise, so rematch would no-op.
            GameView(vm: vm,
                     onReview: { _ in recordIfNeeded(vm); self.route = .review(makeReview(from: vm)) },
                     onRematch: { recordIfNeeded(vm); self.route = .game(rematch(vm)) },
                     onExit: { recordIfNeeded(vm); self.route = nil })
                .id(vm.id)
        case let .review(rvm):
            ReviewView(vm: rvm, onExit: { self.route = nil })
                .id(rvm.id)
        }
    }

    private func startGame(_ config: NewGameConfig) {
        let vm = GameViewModel(timeControl: config.timeControl, opponent: config.opponent,
                               humanColor: config.humanColor, settings: settings)
        route = .game(vm)
    }

    private func rematch(_ vm: GameViewModel) -> GameViewModel {
        GameViewModel(timeControl: vm.game.timeControl, opponent: vm.game.opponent,
                      humanColor: vm.game.humanColor?.opposite, settings: settings)
    }

    private func makeReview(from vm: GameViewModel) -> ReviewViewModel {
        let g = vm.game
        return ReviewViewModel(history: g.history,
                               startFEN: g.history.first?.fenBefore ?? Position.standard.fen,
                               result: ResultSummary(outcome: g.outcome, termination: g.termination ?? .checkmate),
                               whiteName: playerName(.white, vm), blackName: playerName(.black, vm),
                               perspective: g.humanColor ?? .white)
    }

    private func reviewArchived(_ g: ArchivedGame) {
        route = .review(ReviewViewModel(history: g.history, startFEN: g.startFEN, result: g.resultSummary,
                                        whiteName: g.whiteName, blackName: g.blackName,
                                        perspective: g.humanColor ?? .white))
    }

    private func recordIfNeeded(_ vm: GameViewModel) {
        guard vm.game.isGameOver, !recorded.contains(vm.id) else { return }
        recorded.insert(vm.id)
        archive.record(vm.game, whiteName: playerName(.white, vm), blackName: playerName(.black, vm))
    }

    private func playerName(_ side: Side, _ vm: GameViewModel) -> String {
        switch vm.game.opponent {
        case let .computer(d): return side == vm.game.humanColor ? "You" : d.name
        case .localHuman: return side.fullName
        case let .online(_, name): return side == vm.game.humanColor ? "You" : name
        }
    }
}

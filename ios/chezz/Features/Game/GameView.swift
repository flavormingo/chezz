import SwiftUI
import ChessKit

struct GameView: View {
    @Environment(SessionStore.self) private var session
    @State var vm: GameViewModel
    var onReview: (ChessGame) -> Void
    var onRematch: () -> Void
    var onExit: () -> Void

    @State private var showResignConfirm = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(spacing: Spacing.sm) {
                toolbar
                playerBar(side: vm.topSide)
                boardArea
                playerBar(side: vm.bottomSide)
                actionRow
                MoveNavBar(game: vm.game)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)

            // Hidden probe so UI tests can read the half-move count.
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("plyCount")
                .accessibilityValue("\(vm.game.ply)")

            if let pending = vm.game.pendingPromotion {
                PromotionOverlay(color: pending.piece.color,
                                 onSelect: { vm.promote($0) },
                                 onCancel: { vm.cancelPromotion() })
                    .zIndex(2)
            }

            if vm.showResult {
                resultOverlay.zIndex(3).transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSettings = false } } }
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Resign this game?", isPresented: $showResignConfirm, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { vm.resignHuman() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var toolbar: some View {
        HStack {
            Button { vm.stop(); onExit() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
            Spacer()
            VStack(spacing: 1) {
                Text(vm.game.opponent.displayName).font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                Text(vm.game.timeControl.displayName).font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
        }
    }

    private var boardArea: some View {
        BoardView(
            pieces: vm.game.displayPieces,
            perspective: vm.perspective,
            theme: vm.theme,
            selected: vm.game.isBrowsing ? nil : vm.game.selectedSquare,
            legalTargets: vm.game.isBrowsing ? [] : vm.legalTargetSet,
            lastMove: vm.game.displayLastMove,
            checkSquare: vm.game.isBrowsing ? nil : vm.game.checkedKingSquare,
            interactive: !vm.game.isGameOver && !vm.game.isBrowsing,
            showCoordinates: vm.settings.showCoordinates,
            canMoveFrom: { vm.canMoveFrom($0) },
            onSelect: { vm.select($0) },
            onTap: { vm.tap($0) },
            onMove: { vm.move(from: $0, to: $1) }
        )
        .padding(.vertical, Spacing.xs)
    }

    private func playerBar(side: Side) -> some View {
        let clock = vm.game.clock
        return GamePlayerBar(
            name: playerName(side),
            rating: rating(side),
            colorHex: side == vm.bottomSide ? "#34E5A1" : "#8B95A7",
            isBot: isBot(side),
            side: side,
            pieces: vm.game.pieceMap,
            clockSeconds: clock?.remaining(side),
            clockActive: clock?.activeSide == side && !vm.game.isGameOver,
            clockLow: clock?.isLow(side) ?? false,
            toMove: vm.game.sideToMove == side && !vm.game.isGameOver,
            imageURL: avatarURL(side)
        )
    }

    private func avatarURL(_ side: Side) -> URL? {
        guard side == vm.game.humanColor, let url = session.currentUser?.imageURL else { return nil }
        return URL(string: url)
    }

    private var actionRow: some View {
        HStack(spacing: Spacing.sm) {
            GameActionButton(icon: "arrow.up.arrow.down", label: "Flip") { withAnimation { vm.flip() } }
            GameActionButton(icon: "flag.fill", label: "Resign", tint: Palette.danger) {
                if vm.settings.confirmResign { showResignConfirm = true } else { vm.resignHuman() }
            }
        }
        .padding(.bottom, Spacing.xs)
        .disabled(vm.game.isGameOver)
        .opacity(vm.game.isGameOver ? 0.4 : 1)
    }

    private var resultOverlay: some View {
        let outcome = vm.game.outcome
        let summary = ResultSummary(outcome: outcome, termination: vm.game.termination ?? .checkmate)
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: outcome.winner == nil ? "equal.circle.fill" : "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(outcome.winner == nil ? Palette.textSecondary : Palette.gold)
                Text(summary.headline).font(.chezzTitle).foregroundStyle(Palette.textPrimary)
                Text(summary.subtitle).font(.chezzCallout).foregroundStyle(Palette.textSecondary)

                Button { onReview(vm.game) } label: {
                    Label("Game Review", systemImage: "sparkles")
                }
                .buttonStyle(ChezzPrimaryButtonStyle())
                .padding(.top, Spacing.xs)

                Button("Rematch") { onRematch() }
                    .buttonStyle(ChezzSecondaryButtonStyle())
                Button { onExit() } label: { Text("Exit").font(.chezzCallout).foregroundStyle(Palette.textSecondary) }
                    .padding(.top, 2)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 320)
            .chezzCard()
            .padding(Spacing.xl)
        }
    }

    private func playerName(_ side: Side) -> String {
        switch vm.game.opponent {
        case .computer(let d): return side == vm.game.humanColor ? "You" : d.name
        case .localHuman: return side.fullName
        case .online(_, let name): return side == vm.game.humanColor ? "You" : name
        }
    }
    private func isBot(_ side: Side) -> Bool {
        if case .computer = vm.game.opponent { return side != vm.game.humanColor }
        return false
    }
    private func rating(_ side: Side) -> Int? {
        if case .computer(let d) = vm.game.opponent, side != vm.game.humanColor { return d.approxElo }
        return nil
    }
}

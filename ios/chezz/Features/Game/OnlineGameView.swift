import SwiftUI
import ChessKit

struct OnlineGameView: View {
    @State var vm: OnlineGameViewModel
    var onReview: (ChessGame, ResultSummary?, UUID?) -> Void
    var onExit: () -> Void

    @State private var showResign = false
    @State private var showSettings = false
    @State private var showLeaveConfirm = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            VStack(spacing: Spacing.sm) {
                toolbar
                playerBar(side: vm.topSide)
                BoardView(
                    pieces: vm.game.displayPieces,
                    perspective: vm.perspective,
                    theme: vm.settings.boardTheme,
                    selected: vm.game.isBrowsing ? nil : vm.selectedSquare,
                    legalTargets: vm.game.isBrowsing ? [] : (vm.settings.showLegalMoves ? Set(vm.legalTargets) : []),
                    lastMove: vm.game.displayLastMove,
                    checkSquare: vm.game.isBrowsing ? nil : vm.game.checkedKingSquare,
                    interactive: vm.statusActive && !vm.game.isBrowsing,
                    showCoordinates: vm.settings.showCoordinates,
                    canMoveFrom: { vm.canMoveFrom($0) },
                    onSelect: { vm.select($0) },
                    onTap: { vm.tap($0) },
                    onMove: { vm.move(from: $0, to: $1) })
                    .padding(.vertical, Spacing.xs)
                playerBar(side: vm.bottomSide)
                actionRow
                MoveNavBar(game: vm.game)
            }
            .padding(.horizontal, Spacing.md)

            if let p = vm.pendingPromotion {
                let color = vm.game.board.position.piece(at: p.from)?.color ?? vm.mySide
                PromotionOverlay(color: color, onSelect: { vm.completePromotion($0) }, onCancel: { vm.cancelPromotion() })
            }
            if vm.connectionLost { connectionBanner }
            if vm.showResult { resultOverlay }
        }
        .navigationBarBackButtonHidden(true)
        .task { await vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSettings = false } } }
            }
            .preferredColorScheme(.dark)
        }
        .confirmationDialog("Resign this game?", isPresented: $showResign, titleVisibility: .visible) {
            Button("Resign", role: .destructive) { vm.resign() }
            Button("Cancel", role: .cancel) {}
        }
        // Leaving a live game ends it: an abort before move one, a resignation after.
        .confirmationDialog(leaveTitle, isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button(leaveActionLabel, role: .destructive) {
                Task { await vm.leaveGame(); onExit() }
            }
            Button("Keep playing", role: .cancel) {}
        }
    }

    // A timed, still-live game forfeits on leave (confirm first); otherwise leaving just closes the view.
    private func handleLeave() {
        if vm.leavingForfeits {
            showLeaveConfirm = true
        } else {
            vm.stop()
            onExit()
        }
    }
    private var leaveTitle: String {
        vm.leaveIsAbort ? "Leave this game?" : "Leave? This counts as a resignation."
    }
    private var leaveActionLabel: String {
        vm.leaveIsAbort ? "Leave" : "Resign & leave"
    }

    private var toolbar: some View {
        HStack {
            Button { handleLeave() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
            Spacer()
            Text("Online game").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.headline).foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            }
        }
    }

    private func playerBar(side: Side) -> some View {
        GamePlayerBar(
            name: side == .white ? vm.whiteName : vm.blackName,
            rating: nil,
            colorHex: side == .white ? vm.whiteColor : vm.blackColor,
            isBot: false,
            side: side,
            pieces: vm.game.pieceMap,
            clockSeconds: vm.isTimed ? TimeInterval(side == .white ? vm.whiteMs : vm.blackMs) / 1000 : nil,
            clockActive: vm.turn == side && vm.statusActive,
            clockLow: vm.isTimed && (side == .white ? vm.whiteMs : vm.blackMs) <= 20000,
            toMove: vm.turn == side && vm.statusActive,
            imageURL: (side == .white ? vm.whiteImage : vm.blackImage).flatMap { URL(string: $0) })
    }

    private var actionRow: some View {
        HStack(spacing: Spacing.sm) {
            GameActionButton(icon: "arrow.up.arrow.down", label: "Flip") { withAnimation { vm.flip() } }
            GameActionButton(icon: "flag.fill", label: "Resign", tint: Palette.danger) { showResign = true }
        }
        .padding(.bottom, Spacing.xs)
        .disabled(!vm.statusActive)
        .opacity(vm.statusActive ? 1 : 0.4)
    }

    private var connectionBanner: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.xs) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(Palette.warning)
                Text("Reconnecting…").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                Button("Retry") { Task { await vm.start() } }.font(.chezzCaption).foregroundStyle(Palette.mint)
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 100)
        }
    }

    private var resultOverlay: some View {
        let summary = vm.result ?? ResultSummary(outcome: .draw, termination: .abandoned)
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: summary.outcome.winner == nil ? "equal.circle.fill" : "crown.fill")
                    .font(.system(size: 40)).foregroundStyle(summary.outcome.winner == nil ? Palette.textSecondary : Palette.gold)
                Text(summary.headline).font(.chezzTitle).foregroundStyle(Palette.textPrimary)
                Text(summary.subtitle).font(.chezzCallout).foregroundStyle(Palette.textSecondary)
                Button { onReview(vm.game, vm.result, vm.archivedGameId) } label: { Label("Game Review", systemImage: "sparkles") }
                    .buttonStyle(ChezzPrimaryButtonStyle())
                Button { onExit() } label: { Text("Exit").font(.chezzCallout).foregroundStyle(Palette.textSecondary) }
            }
            .padding(Spacing.xl).frame(maxWidth: 320).chezzCard().padding(Spacing.xl)
        }
    }
}

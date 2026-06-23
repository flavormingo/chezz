import SwiftUI

struct FriendsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(PushService.self) private var push

    @State private var vm = FriendsViewModel()
    @State private var showAuth = false
    @State private var searchText = ""
    @State private var challengeTarget: UserProfile?
    @State private var route: FriendRoute?

    enum FriendRoute: Identifiable {
        case online(String)
        case review(ReviewViewModel)
        var id: String {
            switch self { case let .online(g): "online-\(g)"; case let .review(r): "review-\(r.id)" }
        }
    }

    private var myId: String { session.currentUser?.id ?? "" }

    var body: some View {
        NavigationStack {
            Group {
                if session.isSignedIn { signedInContent } else { signedOut }
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.mint)
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(item: $challengeTarget) { friend in
            ChallengeSheet(friend: friend) { tc, color in
                await vm.createChallenge(to: friend, timeControl: tc, color: color)
            }
        }
        .fullScreenCover(item: $route) { route in coverView(route) }
        .task(id: session.isSignedIn) { if session.isSignedIn { await vm.load() } }
        .onChange(of: push.pendingGameId) { _, id in openPushGame(id) }
        .onAppear { openPushGame(push.pendingGameId) }
    }

    private func openPushGame(_ id: String?) {
        guard let id, session.isSignedIn else { return }
        route = .online(id)
        push.pendingGameId = nil
    }

    private var signedOut: some View {
        SignInPromptCard(
            title: "Play with friends",
            message: "Sign in to add friends by username or from your contacts and challenge them",
            icon: "person.2.fill",
            onSignIn: { showAuth = true })
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textSecondary)
            TextField("Search players by username", text: $searchText)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .foregroundStyle(Palette.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, 10)
        .background(Palette.surface2, in: Capsule())
        .padding(.top, Spacing.xs)
    }

    private var signedInContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                searchField
                if !searchText.isEmpty {
                    section("Search") {
                        ForEach(vm.searchResults) { user in personRow(user, action: .add) }
                        if vm.searchResults.isEmpty {
                            Text("No players found.").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                        }
                    }
                } else {
                    contactsCard
                    if !vm.incomingChallenges.isEmpty {
                        section("Challenges") { ForEach(vm.incomingChallenges) { challengeRow($0) } }
                    }
                    if !vm.outgoingChallenges.isEmpty {
                        section("Sent") { ForEach(vm.outgoingChallenges) { outgoingChallengeRow($0) } }
                    }
                    if !vm.activeGames.isEmpty {
                        section("Your games") { ForEach(vm.activeGames) { gameRow($0) } }
                    }
                    if !vm.incomingRequests.isEmpty {
                        section("Friend requests") { ForEach(vm.incomingRequests) { requestRow($0) } }
                    }
                    section("Friends") {
                        if vm.friends.isEmpty {
                            Text("Add friends to challenge them to a game.").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                        }
                        ForEach(vm.friends) { friend in personRow(friend, action: .challenge) }
                        ForEach(vm.contactMatches.filter { m in !vm.friends.contains { $0.id == m.id } }) { personRow($0, action: .add) }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .onChange(of: searchText) { _, q in Task { await vm.search(q) } }
        .refreshable { await vm.load() }
    }

    private var contactsCard: some View {
        Button { Task { await vm.matchContacts() } } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(Palette.mint)
                    .frame(width: 40, height: 40).background(Palette.mintSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Find friends from contacts").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                    Text(contactsSubtitle).font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if vm.contactsState == .loading { ProgressView().tint(Palette.mint) }
            }
            .padding(Spacing.md).chezzCard(fill: Palette.surface, radius: Radius.md)
        }
        .buttonStyle(.plain)
    }
    private var contactsSubtitle: String {
        switch vm.contactsState {
        case .denied: "Enable Contacts access in Settings"
        case .done: "\(vm.contactMatches.count) match\(vm.contactMatches.count == 1 ? "" : "es") found"
        default: "Privately matched, numbers are never shared"
        }
    }

    enum RowAction { case add, challenge }

    private func personRow(_ user: UserProfile, action: RowAction) -> some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: user.name, colorHex: user.avatarColor, size: 40, imageURL: user.imageURL.flatMap { URL(string: $0) })
            VStack(alignment: .leading, spacing: 1) {
                Text(user.name).font(.chezzCallout).foregroundStyle(Palette.textPrimary)
                Text("@\(user.username) · \(user.rating)").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            if user.isFriend || action == .challenge {
                Button("Challenge") { challengeTarget = user }
                    .font(.chezzCaption).foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 12).padding(.vertical, 7).background(Palette.mint, in: Capsule())
            } else {
                Button("Add") { Task { await vm.sendRequest(to: user) } }
                    .font(.chezzCaption).foregroundStyle(Palette.mint)
                    .padding(.horizontal, 12).padding(.vertical, 7).background(Palette.mintSoft, in: Capsule())
            }
        }
        .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func requestRow(_ req: FriendRequestDTO) -> some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: req.from.toUser().name, colorHex: req.from.avatarColor ?? "#34E5A1", size: 40, imageURL: req.from.image.flatMap { URL(string: $0) })
            Text(req.from.toUser().name).font(.chezzCallout).foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { Task { await vm.acceptRequest(req.id) } } label: {
                Image(systemName: "checkmark").foregroundStyle(Palette.onAccent)
                    .frame(width: 32, height: 32).background(Palette.mint, in: Circle())
            }
            Button { Task { await vm.declineRequest(req.id) } } label: {
                Image(systemName: "xmark").foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32).background(Palette.surface2, in: Circle())
            }
        }
        .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func challengeRow(_ c: ChallengeDTO) -> some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: c.from.toUser().name, colorHex: c.from.avatarColor ?? "#34E5A1", size: 40, imageURL: c.from.image.flatMap { URL(string: $0) })
            VStack(alignment: .leading, spacing: 1) {
                Text(c.from.toUser().name).font(.chezzCallout).foregroundStyle(Palette.textPrimary)
                Text(challengeDesc(c)).font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button("Accept") { Task { if let id = await vm.acceptChallenge(c.id) { route = .online(id) } } }
                .font(.chezzCaption).foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 12).padding(.vertical, 7).background(Palette.mint, in: Capsule())
            Button { Task { await vm.declineChallenge(c.id) } } label: {
                Image(systemName: "xmark").foregroundStyle(Palette.textSecondary).frame(width: 30, height: 30)
            }
        }
        .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func outgoingChallengeRow(_ c: ChallengeDTO) -> some View {
        HStack(spacing: Spacing.sm) {
            Avatar(name: c.to.toUser().name, colorHex: c.to.avatarColor ?? "#34E5A1", size: 36, imageURL: c.to.image.flatMap { URL(string: $0) })
            Text("Challenge to \(c.to.toUser().name)").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Cancel") { Task { await vm.cancelChallenge(c.id) } }
                .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
        }
        .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
    }

    private func gameRow(_ g: GameDTO) -> some View {
        let opponent = (g.white?.id == myId ? g.black : g.white)?.toUser().name ?? "Opponent"
        return Button { route = .online(g.id) } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "circle.fill").font(.caption2).foregroundStyle(g.turn != nil && isMyTurn(g) ? Palette.mint : Palette.textTertiary)
                Text("vs \(opponent)").font(.chezzCallout).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(isMyTurn(g) ? "Your move" : "Their move").font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                Image(systemName: "chevron.right").foregroundStyle(Palette.textTertiary)
            }
            .padding(Spacing.sm).chezzCard(fill: Palette.surface, radius: Radius.md)
        }
        .buttonStyle(.plain)
    }

    private func isMyTurn(_ g: GameDTO) -> Bool {
        let mySide = g.white?.id == myId ? "white" : "black"
        return g.turn == mySide
    }
    private func challengeDesc(_ c: ChallengeDTO) -> String {
        if let tc = c.timeControl { return TimeControl(initialSeconds: tc.initialSeconds, incrementSeconds: tc.incrementSeconds).displayName }
        return "Turn-based"
    }

    @ViewBuilder
    private func coverView(_ route: FriendRoute) -> some View {
        switch route {
        case let .online(gameId):
            // .id keyed on gameId: when a push tap swaps an open cover from one game to
            // another, force a fresh OnlineGameView/socket instead of reusing the old @State vm.
            OnlineGameView(
                vm: OnlineGameViewModel(gameId: gameId, myUserId: myId, settings: settings),
                onReview: { game in
                    self.route = .review(ReviewViewModel(
                        history: game.history,
                        startFEN: game.history.first?.fenBefore ?? "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                        result: ResultSummary(outcome: game.outcome, termination: game.termination ?? .checkmate),
                        whiteName: "White", blackName: "Black"))
                },
                onExit: { self.route = nil; Task { await vm.load() } })
                .id(gameId)
        case let .review(rvm):
            ReviewView(vm: rvm, onExit: { self.route = nil })
                .id(rvm.id)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.chezzCaption).foregroundStyle(Palette.textTertiary).textCase(.uppercase)
            content()
        }
    }
}

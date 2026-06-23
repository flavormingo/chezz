import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(PushService.self) private var push
    @State private var tab: Tab = .play
    enum Tab: Hashable { case play, friends, profile }

    var body: some View {
        TabView(selection: $tab) {
            HomeView(onRequestFriends: { tab = .friends })
                .tabItem { Label("Play", systemImage: "crown.fill") }
                .tag(Tab.play)
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(Tab.friends)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "face.smiling") }
                .tag(Tab.profile)
        }
        .tint(Palette.mint)
        .task { await session.bootstrap() }
        .task(priority: .utility) { await StockfishEngine.shared.start() }
        .onChange(of: push.wantsFriendsTab) { _, want in
            if want { tab = .friends; push.wantsFriendsTab = false }
        }
    }
}

struct SignInPromptCard: View {
    var title: String
    var message: String
    var icon: String = "person.crop.circle.badge.plus"
    var onSignIn: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Fixed height so different icons occupy identical vertical space (keeps the tiles aligned).
            Image(systemName: icon)
                .font(.system(size: 34)).foregroundStyle(Palette.mint)
                .frame(height: 40)
            Text(title).font(.chezzTitle2).foregroundStyle(Palette.textPrimary)
            Text(message).font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Sign in", action: onSignIn)
                .buttonStyle(ChezzPrimaryButtonStyle())
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .chezzCard()
    }
}

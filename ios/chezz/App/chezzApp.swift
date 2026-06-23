import SwiftUI

@main
struct ChezzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()
    @State private var archive = GameArchive()
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(archive)
                .environment(session)
                .environment(PushService.shared)
                .tint(Palette.mint)
                .preferredColorScheme(.dark)
        }
    }
}

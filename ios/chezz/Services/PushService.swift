import Foundation
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushService: NSObject {
    static let shared = PushService()

    var pendingGameId: String?
    var wantsFriendsTab = false

    private var deviceTokenHex: String?
    private var uploadedToken: String?

    private override init() { super.init() }

    // Debug builds get sandbox tokens, Release production; the server self-corrects a mismatch.
    static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    func requestAuthorizationAndRegister() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func didRegister(deviceToken: Data) {
        deviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await uploadIfNeeded() }
    }

    func uploadIfNeeded() async {
        guard let hex = deviceTokenHex, hex != uploadedToken else { return }
        guard await APIClient.shared.hasToken else { return }
        do {
            try await APIClient.shared.registerPushToken(hex, environment: Self.environment)
            uploadedToken = hex
        } catch {
            // Leave uploadedToken unset so we retry on the next sign-in or launch.
        }
    }

    func onSignedIn() {
        requestAuthorizationAndRegister()
        Task { await uploadIfNeeded() }
    }

    func onSignedOut() async {
        if let hex = deviceTokenHex {
            try? await APIClient.shared.removePushToken(hex)
        }
        uploadedToken = nil
    }

    fileprivate func handleTap(_ userInfo: [AnyHashable: Any]) {
        wantsFriendsTab = true
        if let gameId = userInfo["gameId"] as? String { pendingGameId = gameId }
    }
}

extension PushService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        handleTap(response.notification.request.content.userInfo)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    var currentUser: UserProfile?
    var isAuthenticating = false

    private let api = APIClient.shared

    var isSignedIn: Bool { currentUser != nil }
    var needsUsername: Bool { currentUser?.needsUsername ?? false }

    func bootstrap() async {
        guard await api.hasToken else { return }
        await refresh()
    }

    func refresh() async {
        do {
            currentUser = try await api.me().toUser()
            PushService.shared.onSignedIn()
        } catch let error as APIError where error.code.hasPrefix("http_4") {
            // 4xx means the token is invalid or expired, so sign out.
            await signOut()
        } catch {
            // Network or other error: keep the current session rather than signing out on a blip.
        }
    }

    func sendEmailCode(_ email: String) async throws { try await api.sendEmailCode(email) }

    func verifyEmailCode(email: String, code: String) async throws {
        try await api.verifyEmailCode(email: email, code: code)
        await refresh()
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await api.signInApple(idToken: idToken, nonce: nonce)
        await refresh()
    }

    func setDiscoveryPhone(_ phoneNumber: String, region: String?) async throws {
        currentUser = try await api.setDiscoveryPhone(phoneNumber, region: region).toUser()
    }
    func clearDiscoveryPhone() async throws {
        try await api.clearDiscoveryPhone()
        // Flip locally so a transient failure of the follow-up refresh can't leave the flag stale.
        currentUser?.hasDiscoveryPhone = false
        currentUser?.discoverable = false
        await refresh()
    }

    func setUsername(_ username: String) async throws {
        try await api.updateUsername(username)
        await refresh()
    }

    func uploadAvatar(_ jpeg: Data) async throws {
        currentUser = try await api.uploadAvatar(jpeg).toUser()
    }
    func removeAvatar() async throws {
        currentUser = try await api.removeAvatar().toUser()
    }

    func usernameAvailable(_ username: String) async throws -> Bool {
        try await api.usernameAvailable(username)
    }

    func startEmailChange(_ newEmail: String) async throws { try await api.startEmailChange(newEmail) }
    func verifyEmailChange(_ otp: String) async throws {
        currentUser = try await api.verifyEmailChange(otp).toUser()
    }

    func updateProfile(displayName: String? = nil, avatarColor: String? = nil, discoverable: Bool? = nil) async throws {
        currentUser = try await api.patchMe(PatchMeBody(username: nil, displayName: displayName,
                                                        avatarColor: avatarColor, discoverable: discoverable)).toUser()
    }

    func signOut() async {
        // Detach the push token first, while the bearer is still valid.
        await PushService.shared.onSignedOut()
        await api.signOutRemote()
        currentUser = nil
    }
}

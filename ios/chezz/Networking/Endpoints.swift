import Foundation

extension APIClient {
    private func q(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    func sendEmailCode(_ email: String) async throws {
        try await postVoid("/api/auth/email-otp/send-verification-otp", body: EmailOtpSendBody(email: email, type: "sign-in"))
    }
    func verifyEmailCode(email: String, code: String) async throws {
        // The session token arrives in the set-auth-token response header (captured by APIClient).
        try await postVoid("/api/auth/sign-in/email-otp", body: EmailOtpVerifyBody(email: email, otp: code))
    }
    func signInApple(idToken: String, nonce: String) async throws {
        try await postVoid("/api/auth/sign-in/social", body: AppleSignInBody(idToken: .init(token: idToken, nonce: nonce)))
    }
    func usernameAvailable(_ username: String) async throws -> Bool {
        try await post("/api/auth/is-username-available", body: UsernameCheckBody(username: username), as: UsernameAvailableResponse.self).available
    }
    func updateUsername(_ username: String) async throws {
        try await postVoid("/api/auth/update-user", body: UpdateUserBody(username: username, displayUsername: username))
    }
    func signOutRemote() async {
        try? await postVoid("/api/auth/sign-out")
        setToken(nil)
    }

    func me() async throws -> ProfileDTO { try await get("/api/v1/me", as: ProfileDTO.self) }
    // Best-effort ping so the server tracks the streak friends see; safe to call once per game start.
    func reportPlayed() async { try? await postVoid("/api/v1/me/played") }
    func patchMe(_ body: PatchMeBody) async throws -> ProfileDTO { try await patch("/api/v1/me", body: body, as: ProfileDTO.self) }
    func setDiscoveryPhone(_ phoneNumber: String, region: String?) async throws -> ProfileDTO {
        try await post("/api/v1/me/discovery-phone", body: DiscoveryPhoneBody(phoneNumber: phoneNumber, region: region), as: ProfileDTO.self)
    }
    func clearDiscoveryPhone() async throws { try await deleteVoid("/api/v1/me/discovery-phone") }
    func registerPushToken(_ token: String, environment: String) async throws {
        try await postVoid("/api/v1/me/push-token", body: PushTokenBody(token: token, environment: environment, platform: "ios"))
    }
    func removePushToken(_ token: String) async throws {
        try await deleteVoid("/api/v1/me/push-token?token=\(q(token))")
    }
    func startEmailChange(_ newEmail: String) async throws {
        try await postVoid("/api/v1/me/email/start", body: NewEmailBody(newEmail: newEmail))
    }
    func verifyEmailChange(_ otp: String) async throws -> ProfileDTO {
        try await post("/api/v1/me/email/verify", body: OtpBody(otp: otp), as: ProfileDTO.self)
    }
    func searchUsers(_ query: String) async throws -> [ProfileDTO] {
        try await get("/api/v1/users/search?q=\(q(query))", as: SearchResponse.self).results
    }
    func matchContacts(_ phoneNumbers: [String], region: String?) async throws -> [ProfileDTO] {
        try await post("/api/v1/contacts/match", body: ContactsBody(phoneNumbers: phoneNumbers, region: region), as: MatchResponse.self).matches
    }

    func friends() async throws -> [ProfileDTO] { try await get("/api/v1/friends", as: FriendsResponse.self).friends }
    func friendRequests() async throws -> FriendRequestsResponse { try await get("/api/v1/friends/requests", as: FriendRequestsResponse.self) }
    func sendFriendRequest(to userId: String) async throws {
        try await postVoid("/api/v1/friends/requests", body: ToUserBody(toUserId: userId))
    }
    func acceptFriendRequest(_ id: String) async throws { try await postVoid("/api/v1/friends/requests/\(id)/accept") }
    func declineFriendRequest(_ id: String) async throws { try await postVoid("/api/v1/friends/requests/\(id)/decline") }
    func unfriend(_ userId: String) async throws { try await deleteVoid("/api/v1/friends/\(userId)") }

    func createChallenge(toUserId: String, kind: String, timeControl: TimeControlDTO?, color: String) async throws -> ChallengeDTO {
        try await post("/api/v1/challenges",
                       body: CreateChallengeBody(toUserId: toUserId, kind: kind, timeControl: timeControl, color: color),
                       as: ChallengeDTO.self)
    }
    func challenges() async throws -> ChallengesResponse { try await get("/api/v1/challenges", as: ChallengesResponse.self) }
    func acceptChallenge(_ id: String) async throws -> String {
        try await post("/api/v1/challenges/\(id)/accept", as: GameIdResponse.self).gameId
    }
    func declineChallenge(_ id: String) async throws { try await postVoid("/api/v1/challenges/\(id)/decline") }
    func cancelChallenge(_ id: String) async throws { try await postVoid("/api/v1/challenges/\(id)/cancel") }

    func games(status: String) async throws -> [GameDTO] { try await get("/api/v1/games?status=\(status)", as: GamesResponse.self).games }
    func game(_ id: String) async throws -> GameDTO { try await get("/api/v1/games/\(id)", as: GameDTO.self) }
    // Durable game-ending over REST (independent of the live socket), used when leaving a live game.
    func resignGame(_ id: String) async throws { try await postVoid("/api/v1/games/\(id)/resign") }
    func abortGame(_ id: String) async throws { try await postVoid("/api/v1/games/\(id)/abort") }

    // Shared Game Review for online games. The canonical review is whatever the server already holds, so
    // uploadGameReview returns the stored copy (which may be another player's if they opened it first).
    func gameReview(_ gameId: String) async throws -> GameReview? {
        try await get("/api/v1/games/\(gameId)/review", as: GameReviewResponse.self).review
    }
    @discardableResult
    func uploadGameReview(_ gameId: String, _ review: GameReview) async throws -> GameReview? {
        try await post("/api/v1/games/\(gameId)/review", body: GameReviewBody(review: review), as: GameReviewResponse.self).review
    }
}

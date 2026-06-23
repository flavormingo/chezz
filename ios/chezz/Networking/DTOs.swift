import Foundation

struct ProfileDTO: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String?
    let rating: Int?
    let avatarColor: String?
    let image: String?
    let isFriend: Bool?
    let discoverable: Bool?

    func toUser() -> UserProfile {
        UserProfile(id: id, username: username, displayName: displayName ?? "",
                    rating: rating ?? 1200, avatarColor: avatarColor ?? "#34E5A1",
                    isFriend: isFriend ?? false, discoverable: discoverable ?? true,
                    imageURL: image)
    }
}

struct SearchResponse: Codable { let results: [ProfileDTO] }
struct MatchResponse: Codable { let matches: [ProfileDTO] }
struct FriendsResponse: Codable { let friends: [ProfileDTO] }
struct UsernameAvailableResponse: Codable { let available: Bool }
struct GameIdResponse: Codable { let gameId: String }

struct FriendRequestDTO: Codable, Identifiable, Hashable {
    let id: String
    let from: ProfileDTO
    let to: ProfileDTO
    let status: String
}
struct FriendRequestsResponse: Codable { let incoming: [FriendRequestDTO]; let outgoing: [FriendRequestDTO] }

struct TimeControlDTO: Codable, Hashable {
    let initialSeconds: Int
    let incrementSeconds: Int
    func toModel() -> TimeControl { TimeControl(initialSeconds: initialSeconds, incrementSeconds: incrementSeconds) }
}

struct ChallengeDTO: Codable, Identifiable, Hashable {
    let id: String
    let from: ProfileDTO
    let to: ProfileDTO
    let kind: String
    let timeControl: TimeControlDTO?
    let color: String
    let status: String
    let gameId: String?
}
struct ChallengesResponse: Codable { let incoming: [ChallengeDTO]; let outgoing: [ChallengeDTO] }

struct GameDTO: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let white: ProfileDTO?
    let black: ProfileDTO?
    let timeControl: TimeControlDTO?
    let status: String
    let result: String?
    let termination: String?
    let movesUci: [String]?
    let pgn: String?
    let fen: String?
    let turn: String?
    let whiteTimeMs: Int?
    let blackTimeMs: Int?
}
struct GamesResponse: Codable { let games: [GameDTO] }

struct EmailOtpSendBody: Encodable { let email: String; let type: String }
struct EmailOtpVerifyBody: Encodable { let email: String; let otp: String }
struct DiscoveryPhoneBody: Encodable { let phoneNumber: String }
struct AppleIdTokenBody: Encodable { let token: String; let nonce: String }
struct AppleSignInBody: Encodable { let provider = "apple"; let idToken: AppleIdTokenBody }
struct UpdateUserBody: Encodable { let username: String; let displayUsername: String }
struct UsernameCheckBody: Encodable { let username: String }
struct ContactsBody: Encodable { let phoneNumbers: [String] }
struct ToUserBody: Encodable { let toUserId: String }
struct CreateChallengeBody: Encodable {
    let toUserId: String
    let kind: String
    let timeControl: TimeControlDTO?
    let color: String
}
struct PushTokenBody: Encodable { let token: String; let environment: String; let platform: String }
struct NewEmailBody: Encodable { let newEmail: String }
struct OtpBody: Encodable { let otp: String }
struct PatchMeBody: Encodable {
    var username: String?
    var displayName: String?
    var avatarColor: String?
    var discoverable: Bool?
}

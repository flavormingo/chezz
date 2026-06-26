import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    var username: String
    var displayName: String
    var rating: Int
    var avatarColor: String
    var isFriend: Bool
    var discoverable: Bool
    var imageURL: String?
    // True once the user has added a discoverable phone number; drives the honest "Findable" state.
    var hasDiscoveryPhone: Bool
    // Lapse-aware consecutive-day play streak from the server (0 when none or lapsed).
    var streak: Int

    init(id: String, username: String, displayName: String = "", rating: Int = 1200,
         avatarColor: String = "#34E5A1", isFriend: Bool = false, discoverable: Bool = true,
         imageURL: String? = nil, hasDiscoveryPhone: Bool = false, streak: Int = 0) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.rating = rating
        self.avatarColor = avatarColor
        self.isFriend = isFriend
        self.discoverable = discoverable
        self.imageURL = imageURL
        self.hasDiscoveryPhone = hasDiscoveryPhone
        self.streak = streak
    }

    var name: String {
        if !displayName.isEmpty { return displayName }
        return username.isEmpty ? "Player" : username
    }

    var needsUsername: Bool { username.isEmpty }
}

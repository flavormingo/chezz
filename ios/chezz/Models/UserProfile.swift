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

    init(id: String, username: String, displayName: String = "", rating: Int = 1200,
         avatarColor: String = "#34E5A1", isFriend: Bool = false, discoverable: Bool = true,
         imageURL: String? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.rating = rating
        self.avatarColor = avatarColor
        self.isFriend = isFriend
        self.discoverable = discoverable
        self.imageURL = imageURL
    }

    var name: String {
        if !displayName.isEmpty { return displayName }
        return username.isEmpty ? "Player" : username
    }

    var needsUsername: Bool { username.isEmpty }
}

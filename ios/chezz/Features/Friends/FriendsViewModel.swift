import Foundation
import Observation
import Contacts

@MainActor
@Observable
final class FriendsViewModel {
    var friends: [UserProfile] = []
    var incomingRequests: [FriendRequestDTO] = []
    var outgoingRequests: [FriendRequestDTO] = []
    var incomingChallenges: [ChallengeDTO] = []
    var outgoingChallenges: [ChallengeDTO] = []
    var activeGames: [GameDTO] = []

    var searchResults: [UserProfile] = []
    var contactMatches: [UserProfile] = []
    var contactsState: ContactsState = .idle
    var loading = false
    var error: String?

    enum ContactsState { case idle, loading, done, denied }

    private let api = APIClient.shared

    func load() async {
        loading = true
        defer { loading = false }
        if let f = try? await api.friends() { friends = f.map { $0.toUser() } }
        if let r = try? await api.friendRequests() { incomingRequests = r.incoming; outgoingRequests = r.outgoing }
        if let c = try? await api.challenges() { incomingChallenges = c.incoming; outgoingChallenges = c.outgoing }
        activeGames = (try? await api.games(status: "active")) ?? []
    }

    func search(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { searchResults = []; return }
        searchResults = (try? await api.searchUsers(q))?.map { $0.toUser() } ?? []
    }

    func sendRequest(to user: UserProfile) async {
        do { try await api.sendFriendRequest(to: user.id); await load() }
        catch { self.error = message(error) }
    }
    func acceptRequest(_ id: String) async { try? await api.acceptFriendRequest(id); await load() }
    func declineRequest(_ id: String) async { try? await api.declineFriendRequest(id); await load() }
    func unfriend(_ userId: String) async { try? await api.unfriend(userId); await load() }

    func matchContacts() async {
        contactsState = .loading
        do {
            let phones = try await ContactsService.requestAndFetchE164()
            // The server caps each request at 1000 numbers, so match in chunks and merge.
            var seen = Set<String>()
            var matches: [UserProfile] = []
            for start in stride(from: 0, to: phones.count, by: 1000) {
                let chunk = Array(phones[start..<min(start + 1000, phones.count)])
                for user in try await api.matchContacts(chunk).map({ $0.toUser() }) where seen.insert(user.id).inserted {
                    matches.append(user)
                }
            }
            contactMatches = matches
            contactsState = .done
        } catch let e as APIError where e.code == "contacts_denied" {
            contactsState = .denied
        } catch {
            self.error = message(error); contactsState = .idle
        }
    }

    func createChallenge(to user: UserProfile, timeControl: TimeControl, color: String) async -> Bool {
        let kind = timeControl.isUntimed ? "correspondence" : "live"
        let tc = timeControl.isUntimed ? nil : TimeControlDTO(initialSeconds: timeControl.initialSeconds, incrementSeconds: timeControl.incrementSeconds)
        do { _ = try await api.createChallenge(toUserId: user.id, kind: kind, timeControl: tc, color: color); await load(); return true }
        catch { self.error = message(error); return false }
    }
    func acceptChallenge(_ id: String) async -> String? {
        let gameId = try? await api.acceptChallenge(id)
        await load()
        return gameId
    }
    func declineChallenge(_ id: String) async { try? await api.declineChallenge(id); await load() }
    func cancelChallenge(_ id: String) async { try? await api.cancelChallenge(id); await load() }

    private func message(_ e: Error) -> String { (e as? APIError)?.message ?? e.localizedDescription }
}

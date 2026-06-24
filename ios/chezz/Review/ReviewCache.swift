import Foundation

// Engine analysis isn't bit-for-bit reproducible run to run (multi-threaded search), so re-opening
// the same game recomputed a slightly different review each time. We instead compute a game's review
// once and reuse it, keyed by the archived game's id, so every re-open shows the identical result
// (and is instant). Session-scoped: a relaunch recomputes once, then it's stable again.
@MainActor
final class ReviewCache {
    static let shared = ReviewCache()
    private var store: [UUID: GameReview] = [:]

    func review(for id: UUID) -> GameReview? { store[id] }
    func save(_ review: GameReview, for id: UUID) { store[id] = review }
}

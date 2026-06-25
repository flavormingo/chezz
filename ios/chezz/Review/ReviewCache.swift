import Foundation

// Engine analysis isn't bit-for-bit reproducible (multi-threaded search), so re-opening the same game
// would recompute a slightly different review each time. We instead compute a game's review once and
// reuse it, keyed by the archived game's id, so every re-open shows the identical result (and is
// instant). Persisted to disk so it stays stable across app launches too, not just within a session.
@MainActor
final class ReviewCache {
    static let shared = ReviewCache()

    private struct Entry: Codable { let id: UUID; let review: GameReview }
    private var entries: [Entry] = []          // most-recent first
    private let fileURL: URL
    private let limit = 100

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("chezz-reviews.json")
        load()
    }

    func review(for id: UUID) -> GameReview? { entries.first { $0.id == id }?.review }

    func save(_ review: GameReview, for id: UUID) {
        entries.removeAll { $0.id == id }
        entries.insert(Entry(id: id, review: review), at: 0)
        if entries.count > limit { entries = Array(entries.prefix(limit)) }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

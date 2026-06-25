import Foundation
import Observation

@MainActor
@Observable
final class GameArchive {
    private(set) var games: [ArchivedGame] = []

    private let fileURL: URL
    private let limit = 100

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("chezz-games.json")
        load()
    }

    @discardableResult
    func record(_ game: ChessGame, whiteName: String, blackName: String,
                result: ResultSummary? = nil, sourceId: String? = nil) -> ArchivedGame? {
        // Online games are over once the server says so even if the local board's outcome lags, so a
        // supplied result counts as game-over. Local games still require the board itself to be done.
        guard !game.history.isEmpty, game.isGameOver || result != nil else { return nil }
        // A finished online game can be opened again later (push tap, "Your games"); never archive twice.
        if let sourceId, let existing = games.first(where: { $0.sourceId == sourceId }) { return existing }
        let archived = ArchivedGame(from: game, whiteName: whiteName, blackName: blackName,
                                    result: result, sourceId: sourceId)
        games.insert(archived, at: 0)
        if games.count > limit { games = Array(games.prefix(limit)) }
        persist()
        return archived
    }

    func delete(_ game: ArchivedGame) {
        games.removeAll { $0.id == game.id }
        persist()
    }

    func clear() {
        games = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        games = (try? JSONDecoder().decode([ArchivedGame].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(games) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

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

    func record(_ game: ChessGame, whiteName: String, blackName: String) {
        guard game.isGameOver, !game.history.isEmpty else { return }
        let archived = ArchivedGame(from: game, whiteName: whiteName, blackName: blackName)
        games.insert(archived, at: 0)
        if games.count > limit { games = Array(games.prefix(limit)) }
        persist()
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

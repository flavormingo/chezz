import XCTest
import ChessKit
@testable import chezz

// Online games end server-side (the local board never sees a resignation/timeout) and used to never be
// archived at all, so friend games were missing from Recent Games. These cover the explicit-result path.
@MainActor
final class GameArchiveTests: XCTestCase {

    private func playedGame() -> ChessGame {
        let game = ChessGame(timeControl: .untimed, opponent: .online(opponentId: "u2", opponentName: "Rico"), humanColor: .white)
        for uci in ["e2e4", "e7e5", "g1f3"] { _ = game.applyUCIMove(uci) }
        XCTAssertFalse(game.isGameOver, "the board is still mid-game; only the server knows it ended")
        return game
    }

    func testOnlineResignationArchivesWithServerResult() {
        let archive = GameArchive()
        let before = archive.games.count
        let result = ResultSummary(outcome: .win(.white), termination: .resignation)

        let saved = archive.record(playedGame(), whiteName: "You", blackName: "Rico", result: result, sourceId: "game-1")

        XCTAssertNotNil(saved, "a server-confirmed finish should archive even if the local board isn't game-over")
        XCTAssertEqual(archive.games.count, before + 1)
        XCTAssertEqual(saved?.outcome, .win(.white))
        XCTAssertEqual(saved?.termination, .resignation)
        XCTAssertEqual(saved?.sourceId, "game-1")
        if let s = saved { archive.delete(s) }
    }

    func testSameOnlineGameIsNotArchivedTwice() {
        let archive = GameArchive()
        let result = ResultSummary(outcome: .win(.black), termination: .timeout)

        let first = archive.record(playedGame(), whiteName: "You", blackName: "Rico", result: result, sourceId: "game-2")
        let countAfterFirst = archive.games.count
        let second = archive.record(playedGame(), whiteName: "You", blackName: "Rico", result: result, sourceId: "game-2")

        XCTAssertEqual(archive.games.count, countAfterFirst, "reopening a finished online game must not duplicate it")
        XCTAssertEqual(first?.id, second?.id)
        if let s = first { archive.delete(s) }
    }

    func testUnfinishedGameWithoutResultIsNotArchived() {
        let archive = GameArchive()
        let before = archive.games.count
        let saved = archive.record(playedGame(), whiteName: "You", blackName: "Rico")
        XCTAssertNil(saved, "an in-progress game with no authoritative result should not archive")
        XCTAssertEqual(archive.games.count, before)
    }
}

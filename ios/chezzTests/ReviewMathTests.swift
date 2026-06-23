import XCTest
import ChessKit
@testable import chezz

final class ReviewMathTests: XCTestCase {

    func testWinPercentMidpoint() {
        XCTAssertEqual(Eval.winPercent(cp: 0), 50, accuracy: 0.001)
    }

    func testWinPercentKnownPoints() {
        XCTAssertEqual(Eval.winPercent(cp: 100), 59.1, accuracy: 1.0)
        XCTAssertEqual(Eval.winPercent(cp: 300), 75, accuracy: 2.0)
        XCTAssertGreaterThan(Eval.winPercent(cp: 1000), 95)
        XCTAssertLessThan(Eval.winPercent(cp: -1000), 5)
    }

    func testAccuracyPerfectWhenNoLoss() {
        XCTAssertEqual(Eval.moveAccuracy(winBefore: 60, winAfter: 65), 100, accuracy: 0.001)
        XCTAssertEqual(Eval.moveAccuracy(winBefore: 60, winAfter: 60), 100, accuracy: 0.001)
    }

    func testAccuracyDecreasesWithLoss() {
        let small = Eval.moveAccuracy(winBefore: 60, winAfter: 55)
        let big = Eval.moveAccuracy(winBefore: 60, winAfter: 30)
        XCTAssertGreaterThan(small, big)
        XCTAssertLessThan(big, 60)
    }

    func testClassificationBands() {
        XCTAssertEqual(MoveClassification.fromExpectedPointsLost(0.01), .excellent)
        XCTAssertEqual(MoveClassification.fromExpectedPointsLost(0.03), .good)
        XCTAssertEqual(MoveClassification.fromExpectedPointsLost(0.08), .inaccuracy)
        XCTAssertEqual(MoveClassification.fromExpectedPointsLost(0.15), .mistake)
        XCTAssertEqual(MoveClassification.fromExpectedPointsLost(0.50), .blunder)
    }

    func testOpeningDetectionPicksDeepest() {
        XCTAssertEqual(OpeningBook.detect(sans: ["e4", "e5", "Nf3", "Nc6", "Bb5"])?.name, "Ruy López")
        XCTAssertEqual(OpeningBook.detect(sans: ["d4", "Nf6", "c4", "g6", "Nc3", "d5"])?.name, "Grünfeld Defense")
        XCTAssertNil(OpeningBook.detect(sans: ["h3"]))
    }

    func testMaterialBalancedAtStart() {
        XCTAssertEqual(Material.net(forSide: .white, fen: Position.standard.fen), 0)
    }

    func testTimeControlDisplay() {
        XCTAssertEqual(TimeControl.minutes(10).displayName, "10 min")
        XCTAssertEqual(TimeControl.minutes(5, increment: 3).displayName, "5 min + 3")
        XCTAssertTrue(TimeControl.untimed.isUntimed)
    }
}

final class ChessGameTests: XCTestCase {
    @MainActor
    func testScholarsMateEndsGame() {
        let game = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        XCTAssertEqual(game.applyUCIMove("e2e4"), true)
        XCTAssertEqual(game.applyUCIMove("e7e5"), true)
        XCTAssertEqual(game.applyUCIMove("f1c4"), true)
        XCTAssertEqual(game.applyUCIMove("b8c6"), true)
        XCTAssertEqual(game.applyUCIMove("d1h5"), true)
        XCTAssertEqual(game.applyUCIMove("g8f6"), true)
        XCTAssertEqual(game.applyUCIMove("h5f7"), true)
        XCTAssertTrue(game.isGameOver)
        XCTAssertEqual(game.outcome, .win(.white))
        XCTAssertEqual(game.termination, .checkmate)
    }

    @MainActor
    func testFinishedGameIsArchivedForReview() {
        let archive = GameArchive()
        let before = archive.games.count
        let game = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        for uci in ["f2f3", "e7e5", "g2g4", "d8h4"] { _ = game.applyUCIMove(uci) }
        XCTAssertTrue(game.isGameOver)
        archive.record(game, whiteName: "You", blackName: "Opponent")
        XCTAssertEqual(archive.games.count, before + 1, "a finished game should be saved for review")
        if let added = archive.games.first { archive.delete(added) }
    }
}

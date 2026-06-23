import XCTest

final class GameplayUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testTapToMoveRegistersAndAIResponds() {
        let app = XCUIApplication()
        app.launch()

        let vsComputer = app.buttons["quick-PlayaRobot"]
        XCTAssertTrue(vsComputer.waitForExistence(timeout: 8), "Home 'Play a Robot' card not found")
        vsComputer.tap()

        let board = app.otherElements["chessboard"]
        XCTAssertTrue(board.waitForExistence(timeout: 8), "Board element not found")

        let ply = app.descendants(matching: .any)["plyCount"]
        XCTAssertTrue(ply.waitForExistence(timeout: 5), "ply probe missing")
        XCTAssertEqual(ply.value as? String, "0", "expected a fresh game")

        // White perspective: e2 ≈ (0.5625, 0.8125), e4 ≈ (0.5625, 0.5625) on the board.
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5625, dy: 0.8125)).tap()
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5625, dy: 0.5625)).tap()

        let madeOne = expectation(for: NSPredicate(format: "value == '1' OR value == '2'"), evaluatedWith: ply)
        wait(for: [madeOne], timeout: 6)
        let repliedTwo = expectation(for: NSPredicate(format: "value == '2'"), evaluatedWith: ply)
        wait(for: [repliedTwo], timeout: 15)
    }

    func testRematchResetsGame() {
        let app = XCUIApplication()
        app.launch()

        let passAndPlay = app.buttons["quick-PassandPlay"]
        XCTAssertTrue(passAndPlay.waitForExistence(timeout: 8), "Home 'Pass and Play' card not found")
        passAndPlay.tap()

        let board = app.otherElements["chessboard"]
        XCTAssertTrue(board.waitForExistence(timeout: 8), "Board element not found")
        let ply = app.descendants(matching: .any)["plyCount"]
        XCTAssertTrue(ply.waitForExistence(timeout: 5), "ply probe missing")
        XCTAssertEqual(ply.value as? String, "0", "expected a fresh game")

        // Fool's mate (white perspective): 1. f3 e5 2. g4 Qh4#. dx=(file+0.5)/8, dy=(8-rank+0.5)/8.
        func move(_ from: CGVector, _ to: CGVector) {
            board.coordinate(withNormalizedOffset: from).tap()
            board.coordinate(withNormalizedOffset: to).tap()
        }
        move(CGVector(dx: 0.6875, dy: 0.8125), CGVector(dx: 0.6875, dy: 0.6875)) // f2-f3
        move(CGVector(dx: 0.5625, dy: 0.1875), CGVector(dx: 0.5625, dy: 0.4375)) // e7-e5
        move(CGVector(dx: 0.8125, dy: 0.8125), CGVector(dx: 0.8125, dy: 0.5625)) // g2-g4
        move(CGVector(dx: 0.4375, dy: 0.0625), CGVector(dx: 0.9375, dy: 0.5625)) // Qd8-h4#

        let mated = expectation(for: NSPredicate(format: "value == '4'"), evaluatedWith: ply)
        wait(for: [mated], timeout: 8)

        let rematch = app.buttons["Rematch"]
        XCTAssertTrue(rematch.waitForExistence(timeout: 5), "result overlay with Rematch not shown after checkmate")
        rematch.tap()

        // The bug: rematch was a no-op (board stays mated, overlay stays). Fixed: fresh game, overlay gone.
        let reset = expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: ply)
        wait(for: [reset], timeout: 6)
        XCTAssertFalse(app.buttons["Rematch"].waitForExistence(timeout: 2), "Rematch overlay should be dismissed after reset")
    }

    func testReviewExplainersOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-chezz-autoreview"]
        app.launch()

        let opening = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Scandinavian'")).firstMatch
        XCTAssertTrue(opening.waitForExistence(timeout: 30), "opening chip not found after analysis")
        opening.tap()
        XCTAssertTrue(app.navigationBars["Opening"].waitForExistence(timeout: 5), "opening info sheet did not present")
        app.buttons["Done"].firstMatch.tap()

        let help = app.buttons["What do the move ratings mean?"]
        XCTAssertTrue(help.waitForExistence(timeout: 5), "glossary button missing")
        help.tap()
        XCTAssertTrue(app.navigationBars["Move ratings"].waitForExistence(timeout: 5), "glossary did not present")
    }
}

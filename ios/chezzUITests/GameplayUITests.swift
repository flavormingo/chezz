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

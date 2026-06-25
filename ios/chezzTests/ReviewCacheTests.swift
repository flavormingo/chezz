import XCTest
import ChessKit
@testable import chezz

// A game's review is computed once and reused so it never changes when re-opened. These guard the
// persistence that makes it stable across app launches (engine analysis is otherwise non-deterministic).
@MainActor
final class ReviewCacheTests: XCTestCase {

    private func sampleReview() -> GameReview {
        let history = [
            PlayedMove(ply: 0, color: .white, san: "e4", uci: "e2e4", fenBefore: "", fenAfter: "", whiteClock: nil, blackClock: nil),
            PlayedMove(ply: 1, color: .black, san: "e5", uci: "e7e5", fenBefore: "", fenAfter: "", whiteClock: nil, blackClock: nil),
        ]
        let positions = [
            PositionEval(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", sideToMove: .white,
                         lines: [AnalysisLine(multipv: 1, scoreCP: 20, mate: nil, pv: ["e2e4"], depth: 12)]),
            PositionEval(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1", sideToMove: .black,
                         lines: [AnalysisLine(multipv: 1, scoreCP: -15, mate: nil, pv: ["e7e5"], depth: 12)]),
            PositionEval(fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2", sideToMove: .white,
                         lines: [AnalysisLine(multipv: 1, scoreCP: 18, mate: nil, pv: ["g1f3"], depth: 12)]),
        ]
        return ReviewEngine.build(history: history, positions: positions,
                                  result: ResultSummary(outcome: .draw, termination: .agreement))
    }

    func testReviewSurvivesEncodeDecode() throws {
        let review = sampleReview()
        let data = try JSONEncoder().encode(review)
        let decoded = try JSONDecoder().decode(GameReview.self, from: data)
        XCTAssertEqual(decoded.whiteAccuracy, review.whiteAccuracy)
        XCTAssertEqual(decoded.blackAccuracy, review.blackAccuracy)
        XCTAssertEqual(decoded.moves.count, review.moves.count)
        XCTAssertEqual(decoded.moves.map(\.classification), review.moves.map(\.classification))
        XCTAssertEqual(decoded.evalWhiteCPSeries, review.evalWhiteCPSeries)
        XCTAssertEqual(decoded.whiteCounts, review.whiteCounts)
        XCTAssertEqual(decoded.result, review.result)
    }

    func testCachedReviewPersistsAcrossInstances() {
        let id = UUID()
        let review = sampleReview()

        ReviewCache().save(review, for: id)        // write, then drop the instance
        let loaded = ReviewCache().review(for: id) // a fresh instance simulates an app relaunch

        XCTAssertNotNil(loaded, "a saved review must survive a fresh cache instance (app relaunch)")
        XCTAssertEqual(loaded?.whiteAccuracy, review.whiteAccuracy)
        XCTAssertEqual(loaded?.moves.map(\.classification), review.moves.map(\.classification))
        XCTAssertEqual(loaded?.evalWhiteCPSeries, review.evalWhiteCPSeries)
    }
}

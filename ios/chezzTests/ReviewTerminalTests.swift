import XCTest
import ChessKit
@testable import chezz

// Regression coverage for terminal-position scoring. A checkmate loaded straight from a FEN used to
// be misread as an equal position (ChessKit's `Board.state` tests the wrong king on FEN load), which
// scored the *winner's* mating move as if its advantage vanished and tanked their accuracy. The
// Fool's Mate game below reproduced the real-world report of a perfect finisher showing ~15% accuracy.
final class ReviewTerminalTests: XCTestCase {

    // 1.f3 e5 2.g4 Qh4# — white (the side to move) is checkmated.
    let foolsMate = "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3"
    // Back-rank mate: white rook on a8 mates the black king, boxed in by its own pawns.
    let backRankMate = "R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1"
    // Classic K+Q vs K stalemate: black to move, no legal move, not in check.
    let stalemate = "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"

    func testTerminalStateDetectsCheckmateFromFEN() {
        guard case .checkmate(let loser) = ReviewEngine.terminalState(fen: foolsMate, sideToMove: .white) else {
            return XCTFail("Fool's Mate should read as checkmate")
        }
        XCTAssertEqual(loser, .white)

        guard case .checkmate(let loser2) = ReviewEngine.terminalState(fen: backRankMate, sideToMove: .black) else {
            return XCTFail("Back-rank mate should read as checkmate")
        }
        XCTAssertEqual(loser2, .black)
    }

    func testTerminalStateTreatsStalemateAsDraw() {
        if case .checkmate = ReviewEngine.terminalState(fen: stalemate, sideToMove: .black) {
            XCTFail("Stalemate must not be scored as checkmate")
        }
    }

    func testEffectiveScoresCheckmateAsLossForSideToMove() {
        let whiteMated = ReviewEngine.effective(PositionEval(fen: foolsMate, sideToMove: .white, lines: []))
        XCTAssertEqual(whiteMated.winWhite, 0)
        XCTAssertEqual(whiteMated.mateWhite, -1)
        XCTAssertLessThan(whiteMated.cpWhite, 0)

        let blackMated = ReviewEngine.effective(PositionEval(fen: backRankMate, sideToMove: .black, lines: []))
        XCTAssertEqual(blackMated.winWhite, 100)
        XCTAssertEqual(blackMated.mateWhite, 1)
        XCTAssertGreaterThan(blackMated.cpWhite, 0)
    }

    func testEffectiveScoresStalemateAsEqual() {
        let eff = ReviewEngine.effective(PositionEval(fen: stalemate, sideToMove: .black, lines: []))
        XCTAssertEqual(eff.winWhite, 50)
        XCTAssertNil(eff.mateWhite)
    }

    // A live position that merely has no engine lines (e.g. a timeout) must never be read as mate.
    func testEffectiveDoesNotInventMateForLivePosition() {
        let eff = ReviewEngine.effective(PositionEval(fen: Position.standard.fen, sideToMove: .white, lines: []))
        XCTAssertEqual(eff.winWhite, 50)
        XCTAssertNil(eff.mateWhite)
    }

    // End-to-end: the player who delivers Fool's Mate must be rewarded, not penalised.
    func testFoolsMateRewardsTheWinner() {
        let history = [
            move(0, .white, "f3", "f2f3"),
            move(1, .black, "e5", "e7e5"),
            move(2, .white, "g4", "g2g4"),
            move(3, .black, "Qh4#", "d8h4"),
        ]
        let positions = [
            pos("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", .white, cp: 20, best: "g1f3"),
            pos("rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR b KQkq - 0 1", .black, cp: 30, best: "e7e5"),
            pos("rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq e6 0 2", .white, cp: -20, best: "g1f3"),
            posMate("rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2", .black, mate: 1, best: "d8h4"),
            PositionEval(fen: foolsMate, sideToMove: .white, lines: []),   // terminal
        ]

        let review = ReviewEngine.build(history: history, positions: positions, result: nil)

        XCTAssertNotNil(review.blackAccuracy)
        XCTAssertGreaterThan(review.blackAccuracy ?? 0, 90, "the mating side should score near-perfect")
        XCTAssertLessThan(review.whiteAccuracy ?? 100, 60, "the mated side blundered twice")
        XCTAssertEqual(review.evalWhitePctSeries.last, 0, "the final eval should show black winning")

        let last = review.moves.last
        XCTAssertEqual(last?.classification, .best, "Qh4# is the best move")
        XCTAssertEqual(last?.accuracy ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(last?.mateWhiteAfter, -1)
    }

    // MARK: - Helpers

    private func move(_ ply: Int, _ color: Side, _ san: String, _ uci: String) -> PlayedMove {
        PlayedMove(ply: ply, color: color, san: san, uci: uci,
                   fenBefore: "", fenAfter: "", whiteClock: nil, blackClock: nil)
    }

    private func pos(_ fen: String, _ stm: Side, cp: Double, best: String) -> PositionEval {
        PositionEval(fen: fen, sideToMove: stm,
                     lines: [AnalysisLine(multipv: 1, scoreCP: cp, mate: nil, pv: [best], depth: 14)])
    }

    private func posMate(_ fen: String, _ stm: Side, mate: Int, best: String) -> PositionEval {
        PositionEval(fen: fen, sideToMove: stm,
                     lines: [AnalysisLine(multipv: 1, scoreCP: nil, mate: mate, pv: [best], depth: 14)])
    }
}

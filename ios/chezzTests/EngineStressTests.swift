import XCTest
import ChessKit
@testable import chezz

final class EngineStressTests: XCTestCase {

    private func bestMove(_ engine: StockfishEngine, fen: String, difficulty: AIDifficulty, timeout: Double) async -> (move: String?, timedOut: Bool) {
        await withTaskGroup(of: (String?, Bool).self) { group in
            group.addTask { (await engine.bestMove(forFEN: fen, difficulty: difficulty), false) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return (nil, true)
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
    }

    @MainActor
    func testEnginePlaysManyMovesWithoutHanging() async throws {
        let engine = StockfishEngine.shared
        guard await engine.isAvailableEnsuringStart() else {
            throw XCTSkip("Stockfish nets not present in the test bundle, run scripts/fetch-nnue.sh")
        }

        let game = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        for ply in 0..<24 {
            if game.isGameOver { break }
            let fen = game.board.position.fen
            let difficulty: AIDifficulty = (ply % 2 == 0) ? .casual : .intermediate
            let result = await bestMove(engine, fen: fen, difficulty: difficulty, timeout: 8)
            XCTAssertFalse(result.timedOut, "ENGINE HUNG at ply \(ply), difficulty \(difficulty.name), fen: \(fen)")
            guard let move = result.move else {
                XCTFail("Engine returned nil (no move) at ply \(ply), fen: \(fen)")
                break
            }
            XCTAssertTrue(game.applyUCIMove(move), "Failed to apply engine move \(move) at fen: \(fen)")
        }
    }

    @MainActor
    func testReviewSpeed() async throws {
        guard await StockfishEngine.shared.isAvailableEnsuringStart() else {
            throw XCTSkip("Stockfish nets not present in the test bundle")
        }
        let game = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        let moves = ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3",
                     "a7a6", "f1e2", "e7e5", "d4b3", "f8e7", "e1g1", "e8g8", "c1e3"]
        for m in moves { XCTAssertTrue(game.applyUCIMove(m), "setup \(m)") }

        let start = Date()
        let review = await ReviewEngine().run(history: game.history,
                                              startFEN: game.history.first?.fenBefore ?? "",
                                              result: nil)
        let elapsed = Date().timeIntervalSince(start)
        print("REVIEW_TIMING: \(game.history.count) plies analyzed in \(String(format: "%.2f", elapsed))s (\(String(format: "%.0f", elapsed / Double(game.history.count + 1) * 1000))ms/position), DEBUG build")
        XCTAssertEqual(review.moves.count, game.history.count)
    }

    @MainActor
    func testAnalysisIsDeterministic() async throws {
        let engine = StockfishEngine.shared
        guard await engine.isAvailableEnsuringStart() else {
            throw XCTSkip("Stockfish nets not present in the test bundle")
        }
        // The same position analyzed twice must yield identical eval/best move, or a re-opened
        // review shows different accuracy each time (the bug). Single-thread + cleared TT guarantee it.
        let fen = "rnbqkb1r/1p2pppp/p2p1n2/8/3NP3/2N5/PPP2PPP/R1BQKB1R w KQkq - 0 6"
        let a1 = await engine.analyze(fen: fen)
        let a2 = await engine.analyze(fen: fen)
        XCTAssertFalse(a1.isEmpty, "analysis returned no lines")
        XCTAssertEqual(a1.map(\.bestMove), a2.map(\.bestMove), "best moves differ between runs")
        XCTAssertEqual(a1.map(\.scoreCP), a2.map(\.scoreCP), "evals differ between runs")
        XCTAssertEqual(a1.map(\.mate), a2.map(\.mate), "mate scores differ between runs")
    }

    @MainActor
    func testEngineRepliesAfterCaptures() async throws {
        let engine = StockfishEngine.shared
        guard await engine.isAvailableEnsuringStart() else {
            throw XCTSkip("Stockfish nets not present in the test bundle")
        }
        let game = ChessGame(timeControl: .untimed, opponent: .localHuman, humanColor: nil)
        for m in ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5c6"] {
            XCTAssertTrue(game.applyUCIMove(m), "setup move \(m) failed")
        }
        let fen = game.board.position.fen
        let result = await bestMove(engine, fen: fen, difficulty: .casual, timeout: 8)
        XCTAssertFalse(result.timedOut, "Engine hung after Bxc6, fen: \(fen)")
        XCTAssertNotNil(result.move, "Engine returned no recapture, fen: \(fen)")
    }
}

import SwiftUI
import Observation
import ChessKit

// Server-authoritative: local moves are sent and only applied on the server's echo; clocks come from the server.
@MainActor
@Observable
final class OnlineGameViewModel: Identifiable {
    let id = UUID()
    let gameId: String
    let myUserId: String
    let settings: AppSettings
    private let archive: GameArchive
    private var didArchive = false
    // Id of this game's archived record; used as the review cache key so the post-game review and the
    // recent-games review share one cached result instead of each analyzing (and differing slightly).
    private(set) var archivedGameId: UUID?

    private(set) var game: ChessGame
    var mySide: Side = .white
    var perspective: Side = .white
    var whiteName = "White"
    var blackName = "Black"
    var whiteColor = "#34E5A1"
    var blackColor = "#8B95A7"
    var whiteImage: String?
    var blackImage: String?
    var whiteMs = 0
    var blackMs = 0
    var isTimed = false
    var turn: Side = .white
    var statusActive = true
    var result: ResultSummary?
    var showResult = false
    var connectionLost = false
    var awaitingServer = false

    var selectedSquare: Square?
    var legalTargets: [Square] = []
    var pendingPromotion: (from: Square, to: Square)?

    private let socket = GameSocketClient()
    private let api = APIClient.shared
    private var streamTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var didInitPerspective = false

    init(gameId: String, myUserId: String, settings: AppSettings, archive: GameArchive) {
        self.gameId = gameId
        self.myUserId = myUserId
        self.settings = settings
        self.archive = archive
        self.game = ChessGame(timeControl: .untimed, opponent: .online(opponentId: "", opponentName: "Opponent"), humanColor: .white)
    }

    // Save a finished online game to the local archive so it appears in Recent Games. Uses the server's
    // authoritative result (resignations/timeouts never reach the local board) and de-dupes on gameId.
    private func archiveIfFinished() {
        guard !didArchive, let result, !game.history.isEmpty else { return }
        didArchive = true
        archivedGameId = archive.record(game, whiteName: whiteName, blackName: blackName,
                                        result: result, sourceId: gameId)?.id
    }

    var topSide: Side { perspective.opposite }
    var bottomSide: Side { perspective }
    var isMyTurn: Bool { statusActive && turn == mySide && !awaitingServer }

    func start() async {
        settings.recordPlayedToday()
        streamTask?.cancel()
        clockTask?.cancel()
        watchdog?.cancel()
        guard let token = await api.bearerToken else { connectionLost = true; return }
        connectionLost = false
        let stream = await socket.connect(token: token)
        await socket.join(gameId)
        streamTask = Task { [weak self] in
            for await env in stream { self?.handle(env) }
            // Only report a real drop; a reconnect cancels this task before swapping the stream.
            if !Task.isCancelled { self?.connectionLost = true }
        }
        startClock()
    }

    func stop() {
        streamTask?.cancel()
        clockTask?.cancel()
        watchdog?.cancel()
        Task { await socket.disconnect() }
    }

    func tap(_ sq: Square) {
        guard isMyTurn else { return }
        if let sel = selectedSquare, legalTargets.contains(sq) {
            intendMove(from: sel, to: sq); return
        }
        if let p = game.board.position.piece(at: sq), p.color == mySide {
            selectedSquare = sq
            legalTargets = game.board.legalMoves(forPieceAt: sq)
        } else {
            clearSelection()
        }
    }
    func select(_ sq: Square) {
        guard isMyTurn, let p = game.board.position.piece(at: sq), p.color == mySide else { return }
        selectedSquare = sq
        legalTargets = game.board.legalMoves(forPieceAt: sq)
    }
    func move(from: Square, to: Square) {
        guard isMyTurn, legalTargets(forFrom: from).contains(to) else { clearSelection(); return }
        intendMove(from: from, to: to)
    }
    func canMoveFrom(_ sq: Square) -> Bool {
        isMyTurn && game.board.position.piece(at: sq)?.color == mySide
    }
    private func legalTargets(forFrom sq: Square) -> [Square] { game.board.legalMoves(forPieceAt: sq) }

    private func intendMove(from: Square, to: Square) {
        if isPromotion(from: from, to: to) {
            pendingPromotion = (from, to)
            clearSelection()
        } else {
            sendMove(from: from, to: to, promo: nil)
        }
    }

    func completePromotion(_ kind: Piece.Kind) {
        guard let p = pendingPromotion else { return }
        sendMove(from: p.from, to: p.to, promo: kind)
        pendingPromotion = nil
    }
    func cancelPromotion() { pendingPromotion = nil }

    private func sendMove(from: Square, to: Square, promo: Piece.Kind?) {
        let promoChar: String = {
            switch promo { case .queen: "q"; case .rook: "r"; case .bishop: "b"; case .knight: "n"; default: "" }
        }()
        let uci = from.notation + to.notation + promoChar
        beginAwaiting()
        clearSelection()
        Task { await socket.move(gameId: gameId, uci: uci) }
    }

    // Wait for the server's echo, with a watchdog that re-syncs if none arrives so the board can't freeze.
    private func beginAwaiting() {
        awaitingServer = true
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard let self, self.awaitingServer else { return }
            if let g = try? await self.api.game(self.gameId) { self.applyState(g) }
            else { self.awaitingServer = false }
        }
    }
    private func clearAwaiting() {
        awaitingServer = false
        watchdog?.cancel()
        watchdog = nil
    }

    func resign() { Task { await socket.resign(gameId: gameId) } }
    func flip() { perspective = perspective.opposite }

    private func clearSelection() { selectedSquare = nil; legalTargets = [] }

    private func isPromotion(from: Square, to: Square) -> Bool {
        guard let p = game.board.position.piece(at: from), p.kind == .pawn else { return false }
        return to.rank.value == 8 || to.rank.value == 1
    }

    private func handle(_ env: ServerEnvelope) {
        switch env.type {
        case "gameState":
            if let g = env.game { applyState(g) }
        case "move":
            if let uci = env.uci {
                guard game.applyUCIMove(uci) else {
                    // Local board drifted from the server; re-sync authoritatively.
                    Task { if let g = try? await api.game(gameId) { applyState(g) } }
                    return
                }
                clearAwaiting()
                if let s = env.turn { turn = (s == "black") ? .black : .white }
                if let w = env.whiteTimeMs { whiteMs = w }
                if let b = env.blackTimeMs { blackMs = b }
                clearSelection()
                let event: Feedback.Event = uci.count > 4 ? .promote
                    : (game.lastSAN?.contains("x") == true ? .capture : .move)
                Feedback.play(event, haptics: settings.hapticsEnabled, sound: settings.soundEnabled)
            }
        case "gameOver":
            clearAwaiting()
            statusActive = false
            result = Self.summary(result: env.result, termination: env.termination)
            withAnimation { showResult = true }
            Feedback.play(.gameEnd, haptics: settings.hapticsEnabled, sound: settings.soundEnabled)
            archiveIfFinished()
        case "error":
            clearAwaiting()
            Task { if let g = try? await api.game(gameId) { applyState(g) } }
        default:
            break
        }
    }

    private func applyState(_ g: GameDTO) {
        mySide = (g.white?.id == myUserId) ? .white : .black
        if !didInitPerspective { perspective = mySide; didInitPerspective = true }
        connectionLost = false
        whiteName = g.white?.toUser().name ?? "White"
        blackName = g.black?.toUser().name ?? "Black"
        whiteColor = g.white?.avatarColor ?? "#34E5A1"
        blackColor = g.black?.avatarColor ?? "#8B95A7"
        whiteImage = g.white?.image
        blackImage = g.black?.image
        isTimed = g.timeControl != nil
        whiteMs = g.whiteTimeMs ?? 0
        blackMs = g.blackTimeMs ?? 0
        turn = (g.turn == "black") ? .black : .white
        clearAwaiting()

        let opponentName = mySide == .white ? blackName : whiteName
        let opponentId = (mySide == .white ? g.black?.id : g.white?.id) ?? ""
        let ng = ChessGame(timeControl: .untimed, opponent: .online(opponentId: opponentId, opponentName: opponentName), humanColor: mySide)
        for uci in g.movesUci ?? [] { _ = ng.applyUCIMove(uci) }
        game = ng
        clearSelection()

        statusActive = g.status == "active"
        if g.status != "active" {
            result = Self.summary(result: g.result, termination: g.termination)
            showResult = result != nil
            archiveIfFinished()
        }
    }

    private func startClock() {
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                guard self.statusActive, self.isTimed else { continue }
                if self.turn == .white { self.whiteMs = max(0, self.whiteMs - 250) }
                else { self.blackMs = max(0, self.blackMs - 250) }
            }
        }
    }

    static func summary(result: String?, termination: String?) -> ResultSummary {
        let outcome: GameOutcome = result == "white" ? .win(.white) : (result == "black" ? .win(.black) : .draw)
        let term: Termination
        switch termination {
        case "checkmate": term = .checkmate
        case "resignation": term = .resignation
        case "timeout": term = .timeout
        case "stalemate": term = .stalemate
        case "agreement": term = .agreement
        case "insufficient", "insufficientMaterial": term = .insufficientMaterial
        case "fiftyMove": term = .fiftyMove
        case "repetition": term = .repetition
        default: term = .abandoned
        }
        return ResultSummary(outcome: outcome, termination: term)
    }
}

import Foundation
import Observation
import ChessKit

@MainActor
@Observable
final class ChessClock {
    let timeControl: TimeControl
    private(set) var white: TimeInterval
    private(set) var black: TimeInterval
    private(set) var activeSide: Side?
    private(set) var flagged: Side?

    @ObservationIgnored var onFlag: ((Side) -> Void)?

    @ObservationIgnored private var lastTick: Date?
    @ObservationIgnored private var timer: Timer?

    var isRunning: Bool { activeSide != nil }

    init(timeControl: TimeControl) {
        self.timeControl = timeControl
        let t = TimeInterval(timeControl.initialSeconds)
        self.white = t
        self.black = t
    }

    func remaining(_ side: Side) -> TimeInterval { side == .white ? white : black }
    func isLow(_ side: Side) -> Bool { !timeControl.isUntimed && remaining(side) <= 20 }

    func start(activeSide side: Side) {
        guard !timeControl.isUntimed, flagged == nil else { return }
        activeSide = side
        lastTick = Date()
        startTimer()
    }

    func didMove(_ side: Side) {
        guard !timeControl.isUntimed, flagged == nil else { return }
        commitElapsed()
        // If the commit flagged the mover, the game is over; don't restart the clock.
        guard flagged == nil else { return }
        add(TimeInterval(timeControl.incrementSeconds), to: side)
        activeSide = side.opposite
        lastTick = Date()
    }

    func stop() {
        commitElapsed()
        activeSide = nil
        stopTimer()
    }

    private func add(_ t: TimeInterval, to side: Side) {
        if side == .white { white += t } else { black += t }
    }

    private func commitElapsed() {
        guard let side = activeSide, let last = lastTick else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(last)
        lastTick = now
        if side == .white { white = max(0, white - elapsed) } else { black = max(0, black - elapsed) }
        if remaining(side) <= 0, flagged == nil {
            flagged = side
            stop()
            onFlag?(side)
        }
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitElapsed() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}

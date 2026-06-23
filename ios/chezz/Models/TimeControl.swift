import Foundation

// initialSeconds == 0 means untimed (turn-based / correspondence).
struct TimeControl: Codable, Hashable, Identifiable {
    var initialSeconds: Int
    var incrementSeconds: Int

    var id: String { "\(initialSeconds)+\(incrementSeconds)" }
    var isUntimed: Bool { initialSeconds <= 0 }
    var initialMinutes: Int { initialSeconds / 60 }

    init(initialSeconds: Int, incrementSeconds: Int = 0) {
        self.initialSeconds = initialSeconds
        self.incrementSeconds = incrementSeconds
    }

    static func minutes(_ m: Int, increment: Int = 0) -> TimeControl {
        TimeControl(initialSeconds: max(0, m) * 60, incrementSeconds: increment)
    }

    static let untimed   = TimeControl(initialSeconds: 0)
    static let bullet    = TimeControl(initialSeconds: 60,  incrementSeconds: 0)
    static let blitz     = TimeControl(initialSeconds: 180, incrementSeconds: 2)
    static let rapid     = TimeControl(initialSeconds: 600, incrementSeconds: 0)
    static let classical = TimeControl(initialSeconds: 1800, incrementSeconds: 10)

    static let presets: [TimeControl] = [.bullet, .blitz, .rapid, .classical, .untimed]

    var displayName: String {
        if isUntimed { return "Turn-based" }
        let mins = initialMinutes
        let base = mins >= 1 ? "\(mins) min" : "\(initialSeconds) sec"
        return incrementSeconds > 0 ? "\(base) + \(incrementSeconds)" : base
    }
}

import Foundation

// Day-streak math, kept pure (no Date()/UserDefaults) so it is unit-testable. A "day" is a calendar
// day in the given calendar's timezone; playing any game on consecutive days extends the streak.
enum Streak {
    // The streak after playing at `now`, given the prior count and the last day a game was played.
    static func afterPlay(prev: Int, lastPlayed: Date?, now: Date, calendar: Calendar = .current) -> (count: Int, lastPlayed: Date) {
        let today = calendar.startOfDay(for: now)
        guard let lastPlayed else { return (1, today) }
        let last = calendar.startOfDay(for: lastPlayed)
        if last == today { return (max(prev, 1), today) }          // already counted today
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        return (gap == 1 ? prev + 1 : 1, today)                    // consecutive extends; any gap resets
    }

    // The streak to display at `now`: alive if the last play was today or yesterday, else lapsed (0).
    static func current(count: Int, lastPlayed: Date?, now: Date, calendar: Calendar = .current) -> Int {
        guard let lastPlayed, count > 0 else { return 0 }
        let today = calendar.startOfDay(for: now)
        let last = calendar.startOfDay(for: lastPlayed)
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        return (0...1).contains(gap) ? count : 0
    }
}

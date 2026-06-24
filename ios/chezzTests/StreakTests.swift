import XCTest
@testable import chezz

final class StreakTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testFirstPlayStartsAtOne() {
        let r = Streak.afterPlay(prev: 0, lastPlayed: nil, now: day(2026, 6, 24), calendar: cal)
        XCTAssertEqual(r.count, 1)
    }

    func testSameDayDoesNotIncrement() {
        let r = Streak.afterPlay(prev: 3, lastPlayed: day(2026, 6, 24, 9), now: day(2026, 6, 24, 21), calendar: cal)
        XCTAssertEqual(r.count, 3)
    }

    func testConsecutiveDayIncrements() {
        let r = Streak.afterPlay(prev: 3, lastPlayed: day(2026, 6, 23), now: day(2026, 6, 24), calendar: cal)
        XCTAssertEqual(r.count, 4)
    }

    func testGapResetsToOne() {
        let r = Streak.afterPlay(prev: 9, lastPlayed: day(2026, 6, 21), now: day(2026, 6, 24), calendar: cal)
        XCTAssertEqual(r.count, 1)
    }

    func testCurrentAliveTodayOrYesterday() {
        XCTAssertEqual(Streak.current(count: 5, lastPlayed: day(2026, 6, 24), now: day(2026, 6, 24), calendar: cal), 5)
        XCTAssertEqual(Streak.current(count: 5, lastPlayed: day(2026, 6, 23), now: day(2026, 6, 24), calendar: cal), 5)
    }

    func testCurrentLapsesAfterTwoDays() {
        XCTAssertEqual(Streak.current(count: 5, lastPlayed: day(2026, 6, 22), now: day(2026, 6, 24), calendar: cal), 0)
    }

    func testCurrentZeroWhenNeverPlayed() {
        XCTAssertEqual(Streak.current(count: 0, lastPlayed: nil, now: day(2026, 6, 24), calendar: cal), 0)
    }
}

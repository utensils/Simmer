import XCTest
@testable import Simmer

internal final class RelativeTimeFormatterTests: XCTestCase {
    // MARK: - Seconds Tests

    func testJustNow_ZeroSeconds() {
        let now = Date()
        let result = RelativeTimeFormatter.string(from: now, relativeTo: now)
        XCTAssertEqual(result, "just now")
    }

    func testJustNow_OneSecond() {
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1)
        let result = RelativeTimeFormatter.string(from: oneSecondAgo, relativeTo: now)
        XCTAssertEqual(result, "just now")
    }

    func testSeconds_TwoSeconds() {
        let now = Date()
        let twoSecondsAgo = now.addingTimeInterval(-2)
        let result = RelativeTimeFormatter.string(from: twoSecondsAgo, relativeTo: now)
        XCTAssertEqual(result, "2s ago")
    }

    func testSeconds_ThirtySeconds() {
        let now = Date()
        let thirtySecondsAgo = now.addingTimeInterval(-30)
        let result = RelativeTimeFormatter.string(from: thirtySecondsAgo, relativeTo: now)
        XCTAssertEqual(result, "30s ago")
    }

    func testSeconds_FiftyNineSeconds() {
        let now = Date()
        let fiftyNineSecondsAgo = now.addingTimeInterval(-59)
        let result = RelativeTimeFormatter.string(from: fiftyNineSecondsAgo, relativeTo: now)
        XCTAssertEqual(result, "59s ago")
    }

    // MARK: - Minutes Tests

    func testMinutes_OneMinute() {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let result = RelativeTimeFormatter.string(from: oneMinuteAgo, relativeTo: now)
        XCTAssertEqual(result, "1m ago")
    }

    func testMinutes_TwoMinutes() {
        let now = Date()
        let twoMinutesAgo = now.addingTimeInterval(-120)
        let result = RelativeTimeFormatter.string(from: twoMinutesAgo, relativeTo: now)
        XCTAssertEqual(result, "2m ago")
    }

    func testMinutes_FifteenMinutes() {
        let now = Date()
        let fifteenMinutesAgo = now.addingTimeInterval(-900)
        let result = RelativeTimeFormatter.string(from: fifteenMinutesAgo, relativeTo: now)
        XCTAssertEqual(result, "15m ago")
    }

    func testMinutes_FiftyNineMinutes() {
        let now = Date()
        let fiftyNineMinutesAgo = now.addingTimeInterval(-3540)
        let result = RelativeTimeFormatter.string(from: fiftyNineMinutesAgo, relativeTo: now)
        XCTAssertEqual(result, "59m ago")
    }

    // MARK: - Hours Tests

    func testHours_OneHour() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let result = RelativeTimeFormatter.string(from: oneHourAgo, relativeTo: now)
        XCTAssertEqual(result, "1h ago")
    }

    func testHours_TwoHours() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let result = RelativeTimeFormatter.string(from: twoHoursAgo, relativeTo: now)
        XCTAssertEqual(result, "2h ago")
    }

    func testHours_TwelveHours() {
        let now = Date()
        let twelveHoursAgo = now.addingTimeInterval(-43200)
        let result = RelativeTimeFormatter.string(from: twelveHoursAgo, relativeTo: now)
        XCTAssertEqual(result, "12h ago")
    }

    func testHours_TwentyThreeHours() {
        let now = Date()
        let twentyThreeHoursAgo = now.addingTimeInterval(-82800)
        let result = RelativeTimeFormatter.string(from: twentyThreeHoursAgo, relativeTo: now)
        XCTAssertEqual(result, "23h ago")
    }

    // MARK: - Days Tests

    func testDays_OneDay() {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86400)
        let result = RelativeTimeFormatter.string(from: oneDayAgo, relativeTo: now)
        XCTAssertEqual(result, "1d ago")
    }

    func testDays_TwoDays() {
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-172800)
        let result = RelativeTimeFormatter.string(from: twoDaysAgo, relativeTo: now)
        XCTAssertEqual(result, "2d ago")
    }

    func testDays_SevenDays() {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-604800)
        let result = RelativeTimeFormatter.string(from: sevenDaysAgo, relativeTo: now)
        XCTAssertEqual(result, "7d ago")
    }

    func testDays_ThirtyDays() {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-2592000)
        let result = RelativeTimeFormatter.string(from: thirtyDaysAgo, relativeTo: now)
        XCTAssertEqual(result, "30d ago")
    }

    // MARK: - Edge Cases

    func testFutureDate_ReturnsJustNow() {
        let now = Date()
        let future = now.addingTimeInterval(60)
        let result = RelativeTimeFormatter.string(from: future, relativeTo: now)
        XCTAssertEqual(result, "just now")
    }

    func testStringFromNow_UsesCurrentTime() {
        // Create a date a few seconds in the past
        let fewSecondsAgo = Date().addingTimeInterval(-5)
        let result = RelativeTimeFormatter.string(from: fewSecondsAgo)

        // Should be approximately "5s ago", but allow for test execution time
        XCTAssertTrue(result.hasSuffix("s ago") || result == "just now")
    }

    // MARK: - Boundary Tests

    func testBoundary_SixtySeconds_ShowsOneMinute() {
        let now = Date()
        let sixtySecondsAgo = now.addingTimeInterval(-60)
        let result = RelativeTimeFormatter.string(from: sixtySecondsAgo, relativeTo: now)
        XCTAssertEqual(result, "1m ago")
    }

    func testBoundary_SixtyMinutes_ShowsOneHour() {
        let now = Date()
        let sixtyMinutesAgo = now.addingTimeInterval(-3600)
        let result = RelativeTimeFormatter.string(from: sixtyMinutesAgo, relativeTo: now)
        XCTAssertEqual(result, "1h ago")
    }

    func testBoundary_TwentyFourHours_ShowsOneDay() {
        let now = Date()
        let twentyFourHoursAgo = now.addingTimeInterval(-86400)
        let result = RelativeTimeFormatter.string(from: twentyFourHoursAgo, relativeTo: now)
        XCTAssertEqual(result, "1d ago")
    }
}

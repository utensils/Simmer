//
//  MatchEventHandlerTests.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import XCTest
@testable import Simmer

@MainActor
internal final class MatchEventHandlerTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        setenv("XCTestCaseDisableMemoryChecker", "YES", 1)
    }

    func test_handleMatchAppendsHistoryAndNotifiesDelegate() {
        let handler = MatchEventHandler(maxHistoryCount: 5)
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        let pattern = makePattern(name: "Error")

        handler.handleMatch(
            pattern: pattern,
            line: "ERROR: failure",
            lineNumber: 42,
            filePath: "/tmp/error.log"
        )

        XCTAssertEqual(handler.history.count, 1)
        let event = handler.history.first
        XCTAssertEqual(event?.patternID, pattern.id)
        XCTAssertEqual(event?.priority, 0)
        XCTAssertEqual(delegate.detectedEvents.count, 1)
        XCTAssertEqual(delegate.historySnapshots.count, 1)
        XCTAssertEqual(delegate.historySnapshots.first?.count, 1)
    }

    func test_historyPrunedToMaximumCount() {
        let handler = MatchEventHandler(maxHistoryCount: 3)

        (0..<4).forEach { index in
            handler.handleMatch(
                pattern: makePattern(name: "Pattern \(index)"),
                line: "Line \(index)",
                lineNumber: index,
                filePath: "/tmp/file\(index).log"
            )
        }

        XCTAssertEqual(handler.history.count, 3)
        XCTAssertEqual(handler.history.first?.matchedLine, "Line 1")
    }

    func test_recentMatchesReturnsNewestFirst() {
        let handler = MatchEventHandler(maxHistoryCount: 10)

        (0..<5).forEach { index in
            handler.handleMatch(
                pattern: makePattern(name: "P\(index)"),
                line: "Line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        let recent = handler.recentMatches(limit: 3)
        XCTAssertEqual(recent.map(\.matchedLine), ["Line 4", "Line 3", "Line 2"])
    }

    func test_clearHistoryEmptiesAndNotifiesDelegate() {
        let handler = MatchEventHandler(maxHistoryCount: 5)
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        handler.handleMatch(
            pattern: makePattern(name: "Pattern"),
            line: "Line",
            lineNumber: 1,
            filePath: "/tmp/file.log"
        )

        (0..<49).forEach { index in
            handler.handleMatch(
                pattern: makePattern(name: "Pattern"),
                line: "Line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        handler.clearHistory()

        XCTAssertTrue(handler.history.isEmpty)
        XCTAssertEqual(delegate.historySnapshots.last?.count, 0)
        XCTAssertTrue(delegate.warningSnapshots.last?.isEmpty ?? true)
    }

    func test_delegateReceivesEventsInInvocationOrder() {
        let handler = MatchEventHandler(maxHistoryCount: 10)
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        let highPriority = makePattern(name: "High")
        let lowPriority = makePattern(name: "Low")

        handler.handleMatch(
            pattern: highPriority,
            line: "First",
            lineNumber: 1,
            filePath: "/tmp/file.log",
            priority: 0
        )

        handler.handleMatch(
            pattern: lowPriority,
            line: "Second",
            lineNumber: 2,
            filePath: "/tmp/file.log",
            priority: 1
        )

        XCTAssertEqual(delegate.detectedEvents.map(\.patternName), ["High", "Low"])
        XCTAssertEqual(delegate.detectedEvents.first?.priority, 0)
        XCTAssertEqual(delegate.detectedEvents.last?.priority, 1)
    }

    func test_handleMatchStoresProvidedPriority() {
        let handler = MatchEventHandler()
        handler.handleMatch(
            pattern: makePattern(name: "Priority"),
            line: "line",
            lineNumber: 1,
            filePath: "/tmp/file.log",
            priority: 5
        )

        XCTAssertEqual(handler.history.first?.priority, 5)
    }

    func test_recentMatchesWithNonPositiveLimitReturnsEmpty() {
        let handler = MatchEventHandler()
        (0..<3).forEach { index in
            handler.handleMatch(
                pattern: makePattern(name: "Pattern \(index)"),
                line: "line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        XCTAssertTrue(handler.recentMatches(limit: 0).isEmpty)
    }

    func test_warningEmittedAfterThresholdAndDelegateNotified() {
        let handler = MatchEventHandler()
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        let pattern = makePattern(name: "Verbose")
        (0..<50).forEach { index in
            handler.handleMatch(
                pattern: pattern,
                line: "line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        let warnings = delegate.warningSnapshots.last
        XCTAssertEqual(warnings?.count, 1)
        XCTAssertEqual(warnings?.first?.patternID, pattern.id)
    }

    func test_acknowledgeWarningClearsWarningAndResetsStreak() {
        let handler = MatchEventHandler()
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        let pattern = makePattern(name: "Verbose")
        (0..<50).forEach { index in
            handler.handleMatch(
                pattern: pattern,
                line: "line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        handler.acknowledgeWarning(for: pattern.id)
        XCTAssertTrue(handler.activeWarnings.isEmpty)
        XCTAssertTrue(delegate.warningSnapshots.last?.isEmpty ?? false)

        (0..<49).forEach { index in
            handler.handleMatch(
                pattern: pattern,
                line: "line \(index)",
                lineNumber: index,
                filePath: "/tmp/file.log"
            )
        }

        XCTAssertTrue(handler.activeWarnings.isEmpty, "Threshold not yet reached")

        handler.handleMatch(
            pattern: pattern,
            line: "final",
            lineNumber: 999,
            filePath: "/tmp/file.log"
        )

        XCTAssertEqual(handler.activeWarnings.count, 1)
    }

    func test_clearHistoryWhenEmptyDoesNotNotifyDelegate() {
        let handler = MatchEventHandler()
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        handler.clearHistory()

        XCTAssertTrue(delegate.historySnapshots.isEmpty)
        XCTAssertTrue(delegate.warningSnapshots.isEmpty)
    }

    func test_acknowledgeWarningWhenNoWarningExistsDoesNothing() {
        let handler = MatchEventHandler()
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        handler.acknowledgeWarning(for: UUID())

        XCTAssertTrue(delegate.warningSnapshots.isEmpty)
        XCTAssertTrue(handler.activeWarnings.isEmpty)
    }

    func test_warningStreakResetsWhenDifferentPatternMatches() {
        let handler = MatchEventHandler()
        let delegate = MockMatchEventHandlerDelegate()
        handler.delegate = delegate

        let patternA = makePattern(name: "A")
        let patternB = makePattern(name: "B")

        (0..<25).forEach { index in
            handler.handleMatch(
                pattern: patternA,
                line: "A\(index)",
                lineNumber: index,
                filePath: "/tmp/a.log"
            )
        }

        handler.handleMatch(
            pattern: patternB,
            line: "switch",
            lineNumber: 26,
            filePath: "/tmp/b.log"
        )

        (0..<49).forEach { index in
            handler.handleMatch(
                pattern: patternA,
                line: "A again \(index)",
                lineNumber: 27 + index,
                filePath: "/tmp/a.log"
            )
        }

        XCTAssertTrue(
            handler.activeWarnings.isEmpty,
            "Streak reset should prevent warning until threshold reached again"
        )

        handler.handleMatch(
            pattern: patternA,
            line: "final-threshold",
            lineNumber: 200,
            filePath: "/tmp/a.log"
        )

        XCTAssertEqual(handler.activeWarnings.count, 1)
        XCTAssertEqual(delegate.warningSnapshots.last?.first?.patternID, patternA.id)
    }

    // MARK: - Helpers

    private func makePattern(name: String) -> LogPattern {
        LogPattern(
            name: name,
            regex: ".*",
            logPath: "/tmp/file.log",
            color: CodableColor(red: 1, green: 0, blue: 0),
            animationStyle: .glow
        )
    }
}

private final class MockMatchEventHandlerDelegate: MatchEventHandlerDelegate {
    private(set) var detectedEvents: [MatchEvent] = []
    private(set) var historySnapshots: [[MatchEvent]] = []
    fileprivate(set) var warningSnapshots: [[FrequentMatchWarning]] = []

    func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
        detectedEvents.append(event)
    }

    func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
        historySnapshots.append(historyDidUpdate)
    }

    func matchEventHandler(
        _ handler: MatchEventHandler,
        didUpdateWarnings warnings: [FrequentMatchWarning]
    ) {
        warningSnapshots.append(warnings)
    }
}

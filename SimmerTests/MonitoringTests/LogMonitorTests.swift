//
//  LogMonitorTests.swift
//  SimmerTests
//

import AppKit
import XCTest
@testable import Simmer

final class LogMonitorTests: XCTestCase {
  func test_start_createsWatcherForEnabledPatternsOnly() async {
    let enabled = makePattern(name: "Error", enabled: true)
    let disabled = makePattern(name: "Info", enabled: false)

    let (monitor, registry, _, _) = await MainActor.run {
      makeMonitor(
        patterns: [enabled, disabled],
        matcher: MockPatternMatcher()
      )
    }

    await MainActor.run {
      monitor.start()
    }

    let enabledID = await MainActor.run { enabled.id }
    let disabledID = await MainActor.run { disabled.id }

    XCTAssertNotNil(registry.watcher(for: enabledID))
    XCTAssertNil(registry.watcher(for: disabledID))
    XCTAssertEqual(registry.watcher(for: enabledID)?.startCount, 1)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_fileWatcherEventTriggersMatchAndAnimation() async {
    let pattern = makePattern(name: "Critical", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])

    let expectation = expectation(description: "animation started")

    let (monitor, registry, handler, iconAnimator) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher
      )
    }

    let delegate = await MainActor.run { SpyIconAnimatorDelegate(onStart: { expectation.fulfill() }) }
    await MainActor.run { iconAnimator.delegate = delegate }

    await MainActor.run {
      monitor.start()
    }
    let patternID = await MainActor.run { pattern.id }
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    await MainActor.run {
      watcher.send(lines: ["ERROR detected"])
    }

    await fulfillment(of: [expectation], timeout: 1.0)
    let history = await MainActor.run { handler.history }
    XCTAssertEqual(history.count, 1)
    let storedPatternID = await MainActor.run { history.first?.patternID }
    XCTAssertEqual(storedPatternID, patternID)
    XCTAssertEqual(history.first?.lineNumber, 1)
    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_historyUpdateClosureInvokedWhenHistoryUpdates() async {
    let pattern = makePattern(name: "History", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 7), captureGroups: [])

    let expectation = expectation(description: "history updated")

    let (monitor, registry, _, _) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher
      )
    }

    await MainActor.run {
      monitor.onHistoryUpdate = { _ in
        expectation.fulfill()
      }
      monitor.start()
    }

    let patternID = await MainActor.run { pattern.id }
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    await MainActor.run {
      watcher.send(lines: ["History"])
    }

    await fulfillment(of: [expectation], timeout: 1.0)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  // MARK: - Helpers

  private func makePattern(name: String, enabled: Bool) -> LogPattern {
    LogPattern(
      name: name,
      regex: ".*",
      logPath: "/tmp/\(UUID().uuidString).log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: enabled
    )
  }

  @MainActor
  private func makeMonitor(
    patterns: [LogPattern],
    matcher: PatternMatcherProtocol
  ) -> (LogMonitor, TestWatcherRegistry, MatchEventHandler, IconAnimator) {
    let handler = MatchEventHandler()
    let timer = TestAnimationTimer()
    let clock = TestAnimationClock()
    let iconAnimator = IconAnimator(timerFactory: { timer }, clock: clock)
    let registry = TestWatcherRegistry()
    let store = InMemoryStore(initialPatterns: patterns)

    let monitor = LogMonitor(
      configurationStore: store,
      patternMatcher: matcher,
      matchEventHandler: handler,
      iconAnimator: iconAnimator,
      watcherFactory: registry.makeWatcher(for:)
    )

    return (monitor, registry, handler, iconAnimator)
  }
}

// MARK: - Test Doubles

private final class TestWatcherRegistry {
  private var storage: [UUID: StubFileWatcher] = [:]

  func makeWatcher(for pattern: LogPattern) -> FileWatching {
    let watcher = StubFileWatcher(path: pattern.logPath)
    storage[pattern.id] = watcher
    return watcher
  }

  func watcher(for id: UUID) -> StubFileWatcher? {
    storage[id]
  }
}

private final class StubFileWatcher: FileWatching {
  let path: String
  weak var delegate: FileWatcherDelegate?

  private(set) var startCount = 0
  private(set) var stopCount = 0

  init(path: String) {
    self.path = path
  }

  func start() throws {
    startCount += 1
  }

  func stop() {
    stopCount += 1
  }

  @MainActor
  func send(lines: [String]) {
    delegate?.fileWatcher(self, didReadLines: lines)
  }

  @MainActor
  func send(error: FileWatcherError) {
    delegate?.fileWatcher(self, didEncounterError: error)
  }
}

@MainActor
private final class TestAnimationTimer: AnimationTimer {
  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {}
  func stop() {}
}

private struct TestAnimationClock: IconAnimatorClock {
  func now() -> TimeInterval {
    0
  }
}

@MainActor
private final class SpyIconAnimatorDelegate: IconAnimatorDelegate {
  private let onStartHandler: () -> Void

  init(onStart: @escaping () -> Void) {
    onStartHandler = onStart
  }

  func animationDidStart(style: AnimationStyle, color: CodableColor) {
    onStartHandler()
  }

  func animationDidEnd() {}

  func updateIcon(_ image: NSImage) {}
}

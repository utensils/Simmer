//
//  LogMonitorTests.swift
//  SimmerTests
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
final class LogMonitorTests: XCTestCase {
  func test_start_createsWatcherForEnabledPatternsOnly() {
    let enabled = makePattern(name: "Error", enabled: true)
    let disabled = makePattern(name: "Info", enabled: false)
    let store = InMemoryStore(initialPatterns: [enabled, disabled])
    let handler = MatchEventHandler()
    let timer = TestAnimationTimer()
    let clock = TestAnimationClock()
    let iconAnimator = IconAnimator(timerFactory: { timer }, clock: clock)
    let registry = TestWatcherRegistry()

    let monitor = LogMonitor(
      configurationStore: store,
      patternMatcher: MockPatternMatcher(),
      matchEventHandler: handler,
      iconAnimator: iconAnimator,
      watcherFactory: registry.makeWatcher(for:)
    )

    monitor.start()

    XCTAssertNotNil(registry.watcher(for: enabled.id))
    XCTAssertNil(registry.watcher(for: disabled.id))
    XCTAssertEqual(registry.watcher(for: enabled.id)?.startCount, 1)

    monitor.stopAll()
  }

  func test_fileWatcherEventTriggersMatchAndAnimation() {
    let pattern = makePattern(name: "Critical", enabled: true)
    let store = InMemoryStore(initialPatterns: [pattern])
    let handler = MatchEventHandler()
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])

    let timer = TestAnimationTimer()
    let clock = TestAnimationClock()
    let iconAnimator = IconAnimator(timerFactory: { timer }, clock: clock)
    let delegate = SpyIconAnimatorDelegate()
    iconAnimator.delegate = delegate
    let registry = TestWatcherRegistry()

    let monitor = LogMonitor(
      configurationStore: store,
      patternMatcher: matcher,
      matchEventHandler: handler,
      iconAnimator: iconAnimator,
      watcherFactory: registry.makeWatcher(for:)
    )

    monitor.start()
    guard let watcher = registry.watcher(for: pattern.id) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    let expectation = expectation(description: "animation started")
    delegate.onStart = {
      expectation.fulfill()
    }

    watcher.send(lines: ["ERROR detected"])

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(handler.history.count, 1)
    XCTAssertEqual(handler.history.first?.patternID, pattern.id)
    XCTAssertEqual(handler.history.first?.lineNumber, 1)
    monitor.stopAll()
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

  func send(lines: [String]) {
    delegate?.fileWatcher(self, didReadLines: lines)
  }

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
  var onStart: (() -> Void)?

  func animationDidStart(style: AnimationStyle, color: CodableColor) {
    onStart?()
  }

  func animationDidEnd() {}

  func updateIcon(_ image: NSImage) {}
}

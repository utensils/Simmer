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
      watcherFactory: { pattern in
        registry.makeWatcher(for: pattern)
      }
    )

    monitor.start()

    XCTAssertNotNil(registry.record(for: enabled.id))
    XCTAssertNil(registry.record(for: disabled.id))
    XCTAssertEqual(registry.record(for: enabled.id)?.eventSource.resumeCallCount, 1)
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
      watcherFactory: { pattern in
        registry.makeWatcher(for: pattern)
      }
    )

    monitor.start()
    guard let record = registry.record(for: pattern.id) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    let expectation = expectation(description: "animation started")
    delegate.onStart = {
      expectation.fulfill()
    }

    registry.fileSystem.append("ERROR detected\n", to: pattern.logPath)
    record.eventSource.trigger(eventMask: .write)

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
  struct Record {
    let watcher: FileWatcher
    let eventSource: MockFileSystemEventSource
  }

  let fileSystem = MockFileSystem()
  private var records: [UUID: Record] = [:]

  func makeWatcher(for pattern: LogPattern) -> FileWatcher {
    let eventSource = MockFileSystemEventSource()
    let sourceFactory = MockFileSystemEventSourceFactory(source: eventSource)
    let queue = DispatchQueue(label: "com.quantierra.Simmer.tests.filewatcher.\(pattern.id.uuidString)")

    let watcher = FileWatcher(
      path: pattern.logPath,
      fileSystem: fileSystem,
      queue: queue,
      sourceFactory: { fd, mask, queue in
        sourceFactory.makeSource(fileDescriptor: fd, mask: mask, queue: queue)
      }
    )

    records[pattern.id] = Record(watcher: watcher, eventSource: eventSource)
    return watcher
  }

  func record(for id: UUID) -> Record? {
    records[id]
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

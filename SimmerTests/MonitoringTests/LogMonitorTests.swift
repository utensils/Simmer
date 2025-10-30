//
//  LogMonitorTests.swift
//  SimmerTests
//

import AppKit
import XCTest

// swiftlint:disable type_body_length
@testable import Simmer

@MainActor
internal final class LogMonitorTests: XCTestCase {
  func test_start_createsWatcherForEnabledPatternsOnly() async {
    let enabled = makePattern(name: "Error", enabled: true)
    let disabled = makePattern(name: "Info", enabled: false)

    let bundle = makeMonitor(
      patterns: [enabled, disabled],
      matcher: MockPatternMatcher()
    )
    let monitor = bundle.monitor
    let registry = bundle.registry

    monitor.start()

    let enabledID = enabled.id
    let disabledID = disabled.id

    XCTAssertNotNil(registry.watcher(for: enabledID))
    XCTAssertNil(registry.watcher(for: disabledID))
    XCTAssertEqual(registry.watcher(for: enabledID)?.startCount, 1)

    monitor.stopAll()
  }

  func test_initCreatesWatchersForPersistedPatterns() async {
    let pattern = makePattern(name: "Boot", enabled: true)
    let matcher = MockPatternMatcher()

    let bundle = makeMonitor(patterns: [pattern], matcher: matcher)
    let monitor = bundle.monitor
    let registry = bundle.registry

    XCTAssertNotNil(registry.watcher(for: pattern.id))

    monitor.stopAll()
  }

  func test_fileWatcherErrorDisablesPatternAndShowsAlert() async {
    let pattern = makePattern(name: "Errored", enabled: true)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])
    let notificationCenter = NotificationCenter()

    let alertExpectation = expectation(description: "alert presented")
    let alertPresenter = TestAlertPresenter(expectation: alertExpectation)

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      store: store,
      alertPresenter: alertPresenter,
      notificationCenter: notificationCenter
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let storeRef = bundle.store
    let queue = bundle.queue

    let notificationExpectation = expectation(description: "patterns change broadcast")
    notificationExpectation.assertForOverFulfill = false
    let observer = notificationCenter.addObserver(
      forName: .logMonitorPatternsDidChange,
      object: nil,
      queue: .main
    ) { _ in
      notificationExpectation.fulfill()
    }

    monitor.start()

    let patternID = pattern.id
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    watcher.send(error: .permissionDenied(path: pattern.logPath))

    queue.sync { }

    await fulfillment(of: [alertExpectation, notificationExpectation], timeout: 1.0)

    notificationCenter.removeObserver(observer)

    let updated = storeRef.loadPatterns().first { $0.id == patternID }
    XCTAssertEqual(updated?.enabled, false)

    let messages = alertPresenter.messages
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages.first?.message.contains(pattern.logPath) ?? false)

    monitor.stopAll()
  }

  func test_fileWatcherEventTriggersMatchAndAnimation() async {
    let pattern = makePattern(name: "Critical", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])

    let expectation = expectation(description: "animation started")

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let handler = bundle.handler
    let iconAnimator = bundle.iconAnimator

    let delegate = SpyIconAnimatorDelegate(onStart: { expectation.fulfill() })
    iconAnimator.delegate = delegate

    monitor.start()
    let patternID = pattern.id
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    watcher.send(lines: ["ERROR detected"])

    await fulfillment(of: [expectation], timeout: 1.0)
    let history = handler.history
    XCTAssertEqual(history.count, 1)
    let storedPatternID = history.first?.patternID
    XCTAssertEqual(storedPatternID, patternID)
    XCTAssertEqual(history.first?.lineNumber, 1)
    monitor.stopAll()
  }

  func test_latencyMeasurementReportedUnderFiveHundredMilliseconds() async {
    let pattern = makePattern(name: "Latency", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 6), captureGroups: [])
    let dateProvider = TestDateProvider(now: Date(timeIntervalSince1970: 0))

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      dateProvider: dateProvider
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let queue = bundle.queue

    let latencyExpectation = expectation(description: "latency measured")
    var measuredLatency: TimeInterval = .infinity

    monitor.onLatencyMeasured = { latency in
      measuredLatency = latency
      latencyExpectation.fulfill()
    }
    monitor.start()

    let watcher = registry.watcher(for: pattern.id)
    watcher?.send(lines: ["ERROR: latency test"])

    dateProvider.advance(by: 0.005)
    queue.sync { }

    await fulfillment(of: [latencyExpectation], timeout: 1.0)

    XCTAssertLessThan(measuredLatency, 0.5)
    XCTAssertLessThan(measuredLatency, 0.010)

    monitor.stopAll()
  }

  func test_fileWatcherProcessesMultipleLinesInBatch() async {
    let pattern = makePattern(name: "Batch", enabled: true)
    let matcher = MockPatternMatcher()

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let handler = bundle.handler
    let queue = bundle.queue

    let matchExpectation = expectation(description: "match recorded")

    monitor.onHistoryUpdate = { events in
      if !events.isEmpty {
        matchExpectation.fulfill()
      }
    }
    monitor.start()

    let patternID = pattern.id

    matcher.enqueue(nil, for: patternID)
    matcher.enqueue(
      MatchResult(range: NSRange(location: 0, length: 4), captureGroups: []),
      for: patternID
    )
    matcher.enqueue(nil, for: patternID)

    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Expected watcher for pattern")
      return
    }

    watcher.send(lines: ["miss", "test", "other"])

    await fulfillment(of: [matchExpectation], timeout: 1.0)

    queue.sync { }

    let history = handler.history
    XCTAssertEqual(history.count, 1)
    XCTAssertEqual(history.first?.lineNumber, 2)
    XCTAssertEqual(history.first?.matchedLine, "test")

    monitor.stopAll()
  }

  func test_reloadPatterns_disablesWatchersForDisabledPatterns() async {
    let pattern = makePattern(name: "Reloadable", enabled: true)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      store: store
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let storeRef = bundle.store

    monitor.start()

    let patternID = pattern.id
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    XCTAssertEqual(watcher.stopCount, 0)

    var disabled = pattern
    disabled.enabled = false
    do {
      try storeRef.updatePattern(disabled)
    } catch {
      XCTFail("Failed to update pattern in store: \(error)")
    }
    monitor.reloadPatterns()

    XCTAssertEqual(watcher.stopCount, 1)

    monitor.stopAll()
  }

  func test_historyUpdateClosureInvokedWhenHistoryUpdates() async {
    let pattern = makePattern(name: "History", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 7), captureGroups: [])

    let expectation = expectation(description: "history updated")

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher
    )
    let monitor = bundle.monitor
    let registry = bundle.registry

    monitor.onHistoryUpdate = { _ in
      expectation.fulfill()
    }
    monitor.start()

    let patternID = pattern.id
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    watcher.send(lines: ["History"])

    await fulfillment(of: [expectation], timeout: 1.0)

    monitor.stopAll()
  }

  func test_start_respectsWatcherLimit() async {
    let patterns = (0..<25).map { index in
      makePattern(name: "Pattern \(index)", enabled: true)
    }
    let matcher = MockPatternMatcher()

    let bundle = makeMonitor(patterns: patterns, matcher: matcher)
    let monitor = bundle.monitor
    let registry = bundle.registry

    monitor.start()

    for index in 0..<20 {
      let id = patterns[index].id
      XCTAssertNotNil(registry.watcher(for: id), "Expected watcher for pattern index \(index)")
    }

    for index in 20..<25 {
      let id = patterns[index].id
      XCTAssertNil(registry.watcher(for: id), "Did not expect watcher for pattern index \(index)")
    }

    monitor.stopAll()
  }

  func test_setPatternEnabledFalse_stopsWatcherWithoutAlert() async {
    let pattern = makePattern(name: "Toggle", enabled: true)
    let matcher = MockPatternMatcher()
    let alertPresenter = RecordingAlertPresenter()

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      alertPresenter: alertPresenter
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let storeRef = bundle.store

    monitor.start()

    let patternID = pattern.id
    XCTAssertEqual(registry.watcher(for: patternID)?.startCount, 1)

    var disabled = pattern
    disabled.enabled = false
    try? storeRef.updatePattern(disabled)

    monitor.setPatternEnabled(patternID, isEnabled: false)

    XCTAssertEqual(registry.watcher(for: patternID)?.stopCount, 1)
    let messages = alertPresenter.messages
    XCTAssertTrue(messages.isEmpty)
  }

  func test_setPatternEnabledTrue_reloadsWatcherFromStore() async {
    var pattern = makePattern(name: "EnableLater", enabled: false)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      store: store
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let storeRef = bundle.store

    monitor.start()

    XCTAssertNil(registry.watcher(for: pattern.id))

    pattern.enabled = true
    try? storeRef.updatePattern(pattern)

    monitor.setPatternEnabled(pattern.id, isEnabled: true)

    guard let watcher = registry.watcher(for: pattern.id) else {
      XCTFail("Expected watcher after enabling pattern")
      return
    }
    XCTAssertEqual(watcher.startCount, 1)
  }

  func test_manualPathValidationDisablesMissingFileAndShowsAlert() async {
    let missingPath = "/tmp/simmer-missing-\(UUID().uuidString).log"
    let pattern = LogPattern(
      name: "Missing File",
      regex: "error",
      logPath: missingPath,
      color: CodableColor(red: 0.5, green: 0.5, blue: 1),
      animationStyle: .glow,
      enabled: true
    )
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])
    let alertPresenter = RecordingAlertPresenter()

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      store: store,
      alertPresenter: alertPresenter
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let storeRef = bundle.store

    XCTAssertNil(registry.watcher(for: pattern.id), "Watcher should not be created for missing file")

    let updatedPattern = storeRef.loadPatterns().first { $0.id == pattern.id }
    XCTAssertEqual(updatedPattern?.enabled, false, "Pattern should be disabled after validation failure")

    let messages = alertPresenter.messages
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages.first?.message.contains("cannot find") ?? false, "Alert should explain missing file")

    monitor.stopAll()
  }

  func test_lowerPriorityMatchDoesNotOverrideActiveHighPriority() async {
    let high = makePattern(name: "High", enabled: true)
    let low = makePattern(name: "Low", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])
    let dateProvider = TestDateProvider()

    let bundle = makeMonitor(
      patterns: [high, low],
      matcher: matcher,
      dateProvider: dateProvider
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let iconAnimator = bundle.iconAnimator

    let startExpectation = expectation(description: "high priority animation started")
    var startCount = 0
    let delegate = SpyIconAnimatorDelegate {
      startCount += 1
      if startCount == 1 {
        startExpectation.fulfill()
      }
    }

    iconAnimator.delegate = delegate
    monitor.start()

    let highID = high.id
    let lowID = low.id

    guard
      let highWatcher = registry.watcher(for: highID),
      let lowWatcher = registry.watcher(for: lowID)
    else {
      XCTFail("Expected watchers for both patterns")
      return
    }

    highWatcher.send(lines: ["High"])

    await fulfillment(of: [startExpectation], timeout: 1.0)

    dateProvider.advance(by: 0.2)
    lowWatcher.send(lines: ["Low"])

    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertEqual(startCount, 1, "Lower priority match should not start animation while higher is active")

    monitor.stopAll()
  }

  func test_animationUsesHighestPriority_whenFivePatternsMatch() async {
    let patterns = (0..<5).map { index in
      makePattern(name: "Pattern \(index)", enabled: true)
    }
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 1), captureGroups: [])
    let dateProvider = TestDateProvider()

    let bundle = makeMonitor(
      patterns: patterns,
      matcher: matcher,
      dateProvider: dateProvider
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let handler = bundle.handler
    let iconAnimator = bundle.iconAnimator

    var startCount = 0
    let startExpectation = expectation(description: "highest priority animation started once")
    let delegate = SpyIconAnimatorDelegate {
      startCount += 1
      if startCount == 1 {
        startExpectation.fulfill()
      }
    }

    iconAnimator.delegate = delegate
    monitor.start()

    let watchers: [StubFileWatcher] = patterns.compactMap { pattern in
      registry.watcher(for: pattern.id)
    }
    XCTAssertEqual(watchers.count, patterns.count, "Expected watcher for each pattern")

    for watcher in watchers {
      watcher.send(lines: ["match"])
      dateProvider.advance(by: 0.05)
    }

    await fulfillment(of: [startExpectation], timeout: 1.0)
    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertEqual(startCount, 1, "Animation should only start once for highest priority pattern")

    let history = handler.history
    XCTAssertEqual(history.count, patterns.count, "All matches should be recorded")
    XCTAssertEqual(history.first?.patternName, patterns.first?.name, "Highest priority pattern should lead animations")

    monitor.stopAll()
  }

  func test_debounceSkipsRapidAnimationRestarts() async {
    let pattern = makePattern(name: "Debounce", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 3), captureGroups: [])
    let dateProvider = TestDateProvider()

    let bundle = makeMonitor(
      patterns: [pattern],
      matcher: matcher,
      dateProvider: dateProvider
    )
    let monitor = bundle.monitor
    let registry = bundle.registry
    let iconAnimator = bundle.iconAnimator

    let initialStart = expectation(description: "initial animation")
    let restartExpectation = expectation(description: "animation restarted after debounce")
    var startCount = 0

    let delegate = SpyIconAnimatorDelegate {
      startCount += 1
      if startCount == 1 {
        initialStart.fulfill()
      } else if startCount == 2 {
        restartExpectation.fulfill()
      }
    }

    iconAnimator.delegate = delegate
    monitor.start()

    let patternID = pattern.id
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Expected watcher for pattern")
      return
    }

    watcher.send(lines: ["A"])

    await fulfillment(of: [initialStart], timeout: 1.0)

    watcher.send(lines: ["B"])

    try? await Task.sleep(nanoseconds: 150_000_000)
    XCTAssertEqual(startCount, 1, "Debounce should prevent immediate restart")

    dateProvider.advance(by: 0.2)
    watcher.send(lines: ["C"])

    await fulfillment(of: [restartExpectation], timeout: 1.0)
    XCTAssertEqual(startCount, 2)

    monitor.stopAll()
  }

  // MARK: - Helpers

  private struct MonitorBundle {
    let monitor: LogMonitor
    let registry: TestWatcherRegistry
    let handler: MatchEventHandler
    let iconAnimator: IconAnimator
    let store: InMemoryStore
    let queue: DispatchQueue
  }

  private func makePattern(
    name: String,
    enabled: Bool
  ) -> LogPattern {
    let path = "/tmp/\(UUID().uuidString).log"
    FileManager.default.createFile(atPath: path, contents: Data(), attributes: nil)
    addTeardownBlock {
      try? FileManager.default.removeItem(atPath: path)
    }

    return LogPattern(
      name: name,
      regex: ".*",
      logPath: path,
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: enabled
    )
  }

  @MainActor
  private func makeMonitor(
    patterns: [LogPattern],
    matcher: PatternMatcherProtocol,
    store: InMemoryStore? = nil,
    dateProvider: TestDateProvider? = nil,
    alertPresenter: LogMonitorAlertPresenting? = nil,
    notificationCenter: NotificationCenter = NotificationCenter(),
    processingQueue: DispatchQueue? = nil,
    watcherFactory customWatcherFactory: ((LogPattern) -> FileWatching)? = nil
  ) -> MonitorBundle {
    let handler = MatchEventHandler()
    let timer = TestAnimationTimer()
    let clock = TestAnimationClock()
    let iconAnimator = IconAnimator(timerFactory: { timer }, clock: clock)
    let registry = TestWatcherRegistry()
    let backingStore = store ?? InMemoryStore(initialPatterns: patterns)
    let queue = processingQueue ?? DispatchQueue(label: "io.utensils.Simmer.tests.log-monitor-processing")
    let presenter = alertPresenter ?? NoOpAlertPresenter()
    let watcherFactory = customWatcherFactory ?? registry.makeWatcher(for:)

    let monitor = LogMonitor(
      configurationStore: backingStore,
      patternMatcher: matcher,
      matchEventHandler: handler,
      iconAnimator: iconAnimator,
      watcherFactory: watcherFactory,
      dateProvider: dateProvider?.now ?? Date.init,
      processingQueue: queue,
      alertPresenter: presenter,
      notificationCenter: notificationCenter
    )

    return MonitorBundle(
      monitor: monitor,
      registry: registry,
      handler: handler,
      iconAnimator: iconAnimator,
      store: backingStore,
      queue: queue
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

@MainActor
private final class RecordingAlertPresenter: LogMonitorAlertPresenting {
  private(set) var messages: [(title: String, message: String)] = []

  func presentAlert(title: String, message: String) {
    messages.append((title: title, message: message))
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
    delegate?.fileWatcher(
      self,
      didEncounterError: error
    )
  }
}

@MainActor
private final class NoOpAlertPresenter: LogMonitorAlertPresenting {
  func presentAlert(title: String, message: String) {}
}

@MainActor
private final class TestAlertPresenter: LogMonitorAlertPresenting {
  private let expectation: XCTestExpectation?
  private(set) var messages: [(title: String, message: String)] = []

  init(expectation: XCTestExpectation? = nil) {
    self.expectation = expectation
  }

  func presentAlert(title: String, message: String) {
    messages.append((title, message))
    expectation?.fulfill()
  }
}

@MainActor
private final class TestAnimationTimer: AnimationTimer {
  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {}
  func stop() {}
}

private final class TestDateProvider {
  private(set) var current: Date

  init(now: Date = Date()) {
    current = now
  }

  func advance(by interval: TimeInterval) {
    current = current.addingTimeInterval(interval)
  }

  func now() -> Date {
    current
  }
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
// swiftlint:enable type_body_length

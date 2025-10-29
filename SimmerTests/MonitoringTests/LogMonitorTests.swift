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

    let (monitor, registry, _, _, _, _) = await MainActor.run {
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

  func test_initCreatesWatchersForPersistedPatterns() async {
    let pattern = makePattern(name: "Boot", enabled: true)
    let matcher = MockPatternMatcher()

    let (monitor, registry, _, _, _, _) = await MainActor.run {
      makeMonitor(patterns: [pattern], matcher: matcher)
    }

    XCTAssertNotNil(registry.watcher(for: pattern.id))

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_initResolvesBookmarksForPersistedPatterns() async {
    let bookmark = FileBookmark(
      bookmarkData: Data([0x00]),
      filePath: "/tmp/bookmarked.log",
      isStale: false
    )
    let pattern = makePattern(name: "Bookmarked", enabled: true, bookmark: bookmark)
    let matcher = MockPatternMatcher()
    let accessManager = RecordingFileAccessManager()
    accessManager.resolveQueue = [
      .success((URL(fileURLWithPath: bookmark.filePath), false))
    ]

    let (monitor, registry, _, _, _, _) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher,
        fileAccessManager: accessManager
      )
    }

    XCTAssertEqual(accessManager.resolveCallCount, 1)
    XCTAssertNotNil(registry.watcher(for: pattern.id))

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_initRefreshesStaleBookmarks() async {
    let originalBookmark = FileBookmark(
      bookmarkData: Data([0x01]),
      filePath: "/tmp/original.log",
      isStale: false
    )
    let refreshedBookmark = FileBookmark(
      bookmarkData: Data([0x02]),
      filePath: "/tmp/refreshed.log",
      isStale: false
    )
    let pattern = makePattern(name: "Refresh", enabled: true, bookmark: originalBookmark)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])
    let accessManager = RecordingFileAccessManager()
    accessManager.resolveQueue = [
      .success((URL(fileURLWithPath: originalBookmark.filePath), true)),
      .success((URL(fileURLWithPath: refreshedBookmark.filePath), false))
    ]
    accessManager.refreshQueue = [
      .success(refreshedBookmark)
    ]

    let (monitor, registry, _, _, storeRef, _) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher,
        store: store,
        fileAccessManager: accessManager
      )
    }

    XCTAssertEqual(accessManager.refreshCallCount, 1)
    XCTAssertEqual(accessManager.resolveCallCount, 2)
    XCTAssertEqual(storeRef.loadPatterns().first?.bookmark, refreshedBookmark)
    XCTAssertEqual(registry.watcher(for: pattern.id)?.path, refreshedBookmark.filePath)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_fileWatcherErrorDisablesPatternAndShowsAlert() async {
    let pattern = makePattern(name: "Errored", enabled: true)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])
    let notificationCenter = NotificationCenter()

    let alertExpectation = expectation(description: "alert presented")
    let alertPresenter = await MainActor.run {
      TestAlertPresenter(expectation: alertExpectation)
    }

    let (monitor, registry, _, _, storeRef, queue) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher,
        store: store,
        alertPresenter: alertPresenter,
        notificationCenter: notificationCenter
      )
    }

    let notificationExpectation = expectation(description: "patterns change broadcast")
    var notificationFulfilled = false
    let observer = notificationCenter.addObserver(
      forName: .logMonitorPatternsDidChange,
      object: nil,
      queue: nil
    ) { _ in
      guard !notificationFulfilled else { return }
      notificationFulfilled = true
      notificationExpectation.fulfill()
    }

    await MainActor.run {
      monitor.start()
    }

    let patternID = await MainActor.run { pattern.id }
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    await MainActor.run {
      watcher.send(error: .permissionDenied(path: pattern.logPath))
    }

    queue.sync { }

    await fulfillment(of: [alertExpectation, notificationExpectation], timeout: 1.0)

    notificationCenter.removeObserver(observer)

    let updated = storeRef.loadPatterns().first { $0.id == patternID }
    XCTAssertEqual(updated?.enabled, false)

    let messages = await MainActor.run { alertPresenter.messages }
    XCTAssertEqual(messages.count, 1)
    XCTAssertTrue(messages.first?.message.contains(pattern.logPath) ?? false)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_fileWatcherEventTriggersMatchAndAnimation() async {
    let pattern = makePattern(name: "Critical", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])

    let expectation = expectation(description: "animation started")

    let (monitor, registry, handler, iconAnimator, _, _) = await MainActor.run {
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

  func test_fileWatcherProcessesMultipleLinesInBatch() async {
    let pattern = makePattern(name: "Batch", enabled: true)
    let matcher = MockPatternMatcher()

    let (monitor, registry, handler, _, _, queue) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher
      )
    }

    let matchExpectation = expectation(description: "match recorded")

    await MainActor.run {
      monitor.onHistoryUpdate = { events in
        if !events.isEmpty {
          matchExpectation.fulfill()
        }
      }
      monitor.start()
    }

    let patternID = await MainActor.run { pattern.id }

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

    await MainActor.run {
      watcher.send(lines: ["miss", "test", "other"])
    }

    await fulfillment(of: [matchExpectation], timeout: 1.0)

    queue.sync { }

    let history = await MainActor.run { handler.history }
    XCTAssertEqual(history.count, 1)
    XCTAssertEqual(history.first?.lineNumber, 2)
    XCTAssertEqual(history.first?.matchedLine, "test")

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_reloadPatterns_disablesWatchersForDisabledPatterns() async {
    let pattern = makePattern(name: "Reloadable", enabled: true)
    let matcher = MockPatternMatcher()
    let store = InMemoryStore(initialPatterns: [pattern])

    let (monitor, registry, _, _, storeRef, _) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher,
        store: store
      )
    }

    await MainActor.run {
      monitor.start()
    }

    let patternID = await MainActor.run { pattern.id }
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Watcher not created for pattern")
      return
    }

    XCTAssertEqual(watcher.stopCount, 0)

    await MainActor.run {
      var disabled = pattern
      disabled.enabled = false
      do {
        try storeRef.updatePattern(disabled)
      } catch {
        XCTFail("Failed to update pattern in store: \(error)")
      }
      monitor.reloadPatterns()
    }

    XCTAssertEqual(watcher.stopCount, 1)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_historyUpdateClosureInvokedWhenHistoryUpdates() async {
    let pattern = makePattern(name: "History", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 7), captureGroups: [])

    let expectation = expectation(description: "history updated")

    let (monitor, registry, _, _, _, _) = await MainActor.run {
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

  func test_start_respectsWatcherLimit() async {
    let patterns = (0..<25).map { index in
      makePattern(name: "Pattern \(index)", enabled: true)
    }
    let matcher = MockPatternMatcher()

    let (monitor, registry, _, _, _, _) = await MainActor.run {
      makeMonitor(patterns: patterns, matcher: matcher)
    }

    await MainActor.run {
      monitor.start()
    }

    for index in 0..<20 {
      let id = await MainActor.run { patterns[index].id }
      XCTAssertNotNil(registry.watcher(for: id), "Expected watcher for pattern index \(index)")
    }

    for index in 20..<25 {
      let id = await MainActor.run { patterns[index].id }
      XCTAssertNil(registry.watcher(for: id), "Did not expect watcher for pattern index \(index)")
    }

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_lowerPriorityMatchDoesNotOverrideActiveHighPriority() async {
    let high = makePattern(name: "High", enabled: true)
    let low = makePattern(name: "Low", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 5), captureGroups: [])
    let dateProvider = TestDateProvider()

    let (monitor, registry, _, iconAnimator, _, _) = await MainActor.run {
      makeMonitor(
        patterns: [high, low],
        matcher: matcher,
        dateProvider: dateProvider
      )
    }

    let startExpectation = expectation(description: "high priority animation started")
    var startCount = 0
    let delegate = await MainActor.run {
      SpyIconAnimatorDelegate {
        startCount += 1
        if startCount == 1 {
          startExpectation.fulfill()
        }
      }
    }

    await MainActor.run {
      iconAnimator.delegate = delegate
      monitor.start()
    }

    let highID = await MainActor.run { high.id }
    let lowID = await MainActor.run { low.id }

    guard
      let highWatcher = registry.watcher(for: highID),
      let lowWatcher = registry.watcher(for: lowID)
    else {
      XCTFail("Expected watchers for both patterns")
      return
    }

    await MainActor.run {
      highWatcher.send(lines: ["High"])
    }

    await fulfillment(of: [startExpectation], timeout: 1.0)

    await MainActor.run {
      dateProvider.advance(by: 0.2)
      lowWatcher.send(lines: ["Low"])
    }

    try? await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertEqual(startCount, 1, "Lower priority match should not start animation while higher is active")

    await MainActor.run {
      monitor.stopAll()
    }
  }

  func test_debounceSkipsRapidAnimationRestarts() async {
    let pattern = makePattern(name: "Debounce", enabled: true)
    let matcher = MockPatternMatcher()
    matcher.fallbackResult = MatchResult(range: NSRange(location: 0, length: 3), captureGroups: [])
    let dateProvider = TestDateProvider()

    let (monitor, registry, _, iconAnimator, _, _) = await MainActor.run {
      makeMonitor(
        patterns: [pattern],
        matcher: matcher,
        dateProvider: dateProvider
      )
    }

    let initialStart = expectation(description: "initial animation")
    let restartExpectation = expectation(description: "animation restarted after debounce")
    var startCount = 0

    let delegate = await MainActor.run {
      SpyIconAnimatorDelegate {
        startCount += 1
        if startCount == 1 {
          initialStart.fulfill()
        } else if startCount == 2 {
          restartExpectation.fulfill()
        }
      }
    }

    await MainActor.run {
      iconAnimator.delegate = delegate
      monitor.start()
    }

    let patternID = await MainActor.run { pattern.id }
    guard let watcher = registry.watcher(for: patternID) else {
      XCTFail("Expected watcher for pattern")
      return
    }

    await MainActor.run {
      watcher.send(lines: ["A"])
    }

    await fulfillment(of: [initialStart], timeout: 1.0)

    await MainActor.run {
      watcher.send(lines: ["B"])
    }

    try? await Task.sleep(nanoseconds: 150_000_000)
    XCTAssertEqual(startCount, 1, "Debounce should prevent immediate restart")

    await MainActor.run {
      dateProvider.advance(by: 0.2)
      watcher.send(lines: ["C"])
    }

    await fulfillment(of: [restartExpectation], timeout: 1.0)
    XCTAssertEqual(startCount, 2)

    await MainActor.run {
      monitor.stopAll()
    }
  }

  // MARK: - Helpers

  private func makePattern(
    name: String,
    enabled: Bool,
    bookmark: FileBookmark? = nil
  ) -> LogPattern {
    LogPattern(
      name: name,
      regex: ".*",
      logPath: "/tmp/\(UUID().uuidString).log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: enabled,
      bookmark: bookmark
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
    fileAccessManager: FileAccessManaging? = nil
  ) -> (LogMonitor, TestWatcherRegistry, MatchEventHandler, IconAnimator, InMemoryStore, DispatchQueue) {
    let handler = MatchEventHandler()
    let timer = TestAnimationTimer()
    let clock = TestAnimationClock()
    let iconAnimator = IconAnimator(timerFactory: { timer }, clock: clock)
    let registry = TestWatcherRegistry()
    let backingStore = store ?? InMemoryStore(initialPatterns: patterns)
    let queue = processingQueue ?? DispatchQueue(label: "com.quantierra.Simmer.tests.log-monitor-processing")
    let presenter = alertPresenter ?? NoOpAlertPresenter()
    let accessManager = fileAccessManager ?? TestFileAccessManager()

    let monitor = LogMonitor(
      configurationStore: backingStore,
      fileAccessManager: accessManager,
      patternMatcher: matcher,
      matchEventHandler: handler,
      iconAnimator: iconAnimator,
      watcherFactory: registry.makeWatcher(for:),
      dateProvider: dateProvider?.now ?? Date.init,
      processingQueue: queue,
      alertPresenter: presenter,
      notificationCenter: notificationCenter
    )

    return (monitor, registry, handler, iconAnimator, backingStore, queue)
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

private final class TestFileAccessManager: FileAccessManaging {
  func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool) {
    (URL(fileURLWithPath: bookmark.filePath), false)
  }

  func refreshStaleBookmark(_ bookmark: FileBookmark) throws -> FileBookmark {
    bookmark
  }
}

private final class RecordingFileAccessManager: FileAccessManaging {
  var resolveQueue: [Result<(url: URL, isStale: Bool), Error>] = []
  var refreshQueue: [Result<FileBookmark, Error>] = []
  private(set) var resolveCallCount = 0
  private(set) var refreshCallCount = 0

  func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool) {
    resolveCallCount += 1
    if !resolveQueue.isEmpty {
      let result = resolveQueue.removeFirst()
      switch result {
      case .success(let value):
        return value
      case .failure(let error):
        throw error
      }
    }
    return (URL(fileURLWithPath: bookmark.filePath), false)
  }

  func refreshStaleBookmark(_ bookmark: FileBookmark) throws -> FileBookmark {
    refreshCallCount += 1
    if !refreshQueue.isEmpty {
      let result = refreshQueue.removeFirst()
      switch result {
      case .success(let value):
        return value
      case .failure(let error):
        throw error
      }
    }
    return bookmark
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

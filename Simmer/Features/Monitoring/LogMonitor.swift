//
//  LogMonitor.swift
//  Simmer
//
//  Coordinates file watchers, pattern matching, and animation feedback.
//

import Foundation
import os.log

/// Central coordinator that listens to file changes, evaluates patterns, and triggers visual feedback.
final class LogMonitor: NSObject {
  typealias WatcherFactory = (LogPattern) -> FileWatching

  private let configurationStore: ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let watcherFactory: WatcherFactory
  private let stateQueue = DispatchQueue(label: "com.quantierra.Simmer.log-monitor")
  private let logger = OSLog(subsystem: "com.quantierra.Simmer", category: "LogMonitor")
  private let maxWatcherCount = 20
  private let debounceInterval: TimeInterval = 0.1
  private let dateProvider: () -> Date

  private struct WatchContext {
    var pattern: LogPattern
    var lineCount: Int
  }

  private struct WatchEntry {
    var watcher: FileWatching
    var context: WatchContext
  }

  private var entriesByPatternID: [UUID: WatchEntry] = [:]
  private var watcherIdentifiers: [ObjectIdentifier: UUID] = [:]
  private var patternPriorities: [UUID: Int] = [:]
  private var lastAnimationTimestamps: [UUID: Date] = [:]
  private var currentAnimation: (patternID: UUID, priority: Int)?

  init(
    configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
    patternMatcher: PatternMatcherProtocol = RegexPatternMatcher(),
    matchEventHandler: MatchEventHandler,
    iconAnimator: IconAnimator,
    watcherFactory: @escaping WatcherFactory = { pattern in
      FileWatcher(path: pattern.logPath)
    },
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.configurationStore = configurationStore
    self.patternMatcher = patternMatcher
    self.matchEventHandler = matchEventHandler
    self.iconAnimator = iconAnimator
    self.watcherFactory = watcherFactory
    self.dateProvider = dateProvider
    super.init()
    self.matchEventHandler.delegate = self
  }

  /// Exposes the match event handler for UI components that need history access.
  var events: MatchEventHandler {
    matchEventHandler
  }

  /// Invoked on the main actor whenever match history changes.
  @MainActor
  var onHistoryUpdate: (([MatchEvent]) -> Void)?

  /// Reloads patterns from storage and reconciles active watchers.
  func reloadPatterns() {
    let patterns = configurationStore.loadPatterns()
    configureWatchers(for: patterns.filter(\.enabled))
  }

  deinit {
    stopAll()
  }

  /// Loads persisted patterns and begins monitoring enabled entries.
  func start() {
    let patterns = configurationStore.loadPatterns().filter(\.enabled)
    configureWatchers(for: patterns)
  }

  /// Stops all active watchers and clears internal state.
  func stopAll() {
    let activeWatchers: [FileWatching] = stateQueue.sync {
      let current = entriesByPatternID.values.map(\.watcher)
      entriesByPatternID.removeAll()
      watcherIdentifiers.removeAll()
      patternPriorities.removeAll()
      lastAnimationTimestamps.removeAll()
      currentAnimation = nil
      return current
    }

    activeWatchers.forEach { $0.stop() }

    Task { @MainActor [iconAnimator] in
      iconAnimator.stopAnimation()
    }
  }

  private func configureWatchers(for patterns: [LogPattern]) {
    let limitedPatterns = Array(patterns.prefix(maxWatcherCount))
    if patterns.count > maxWatcherCount {
      os_log(
        .error,
        log: logger,
        "Watcher limit exceeded (%{public}d > %{public}d). Additional patterns will not be monitored.",
        patterns.count,
        maxWatcherCount
      )
    }

    let priorities = Dictionary(uniqueKeysWithValues: limitedPatterns.enumerated().map { ($1.id, $0) })

    let identifiersToRemove: [UUID] = stateQueue.sync {
      patternPriorities = priorities
      let existingIDs = Set(entriesByPatternID.keys)
      let incomingIDs = Set(limitedPatterns.map(\.id))
      return Array(existingIDs.subtracting(incomingIDs))
    }

    identifiersToRemove.forEach { removeWatcher(forPatternID: $0) }

    for pattern in limitedPatterns {
      if updatePattern(pattern) { continue }
      addWatcher(for: pattern)
    }
  }

  private func addWatcher(for pattern: LogPattern) {
    let watcher = watcherFactory(pattern)
    watcher.delegate = self
    let stored = stateQueue.sync { () -> Bool in
      guard entriesByPatternID.count < maxWatcherCount else { return false }
      let context = WatchContext(pattern: pattern, lineCount: 0)
      let entry = WatchEntry(watcher: watcher, context: context)
      entriesByPatternID[pattern.id] = entry
      watcherIdentifiers[ObjectIdentifier(watcher)] = pattern.id
      return true
    }

    guard stored else {
      os_log(
        .error,
        log: logger,
        "Watcher limit reached. Unable to monitor pattern '%{public}@' at path '%{public}@'.",
        pattern.name,
        pattern.logPath
      )
      return
    }

    do {
      try watcher.start()
    } catch {
      os_log(
        .error,
        log: logger,
        "Failed to start watcher for pattern '%{public}@' at path '%{public}@': %{public}@",
        pattern.name,
        pattern.logPath,
        String(describing: error)
      )
      removeWatcher(forPatternID: pattern.id)
    }
  }

  @discardableResult
  private func updatePattern(_ pattern: LogPattern) -> Bool {
    let restartNeeded: Bool? = stateQueue.sync {
      guard var entry = entriesByPatternID[pattern.id] else { return nil }
      let needsRestart = entry.context.pattern.logPath != pattern.logPath
      entry.context.pattern = pattern
      entriesByPatternID[pattern.id] = entry
      return needsRestart
    }

    guard let restartNeeded else { return false }

    if restartNeeded {
      removeWatcher(forPatternID: pattern.id)
      addWatcher(for: pattern)
    }

    return true
  }

  private func removeWatcher(forPatternID patternID: UUID) {
    let entry: WatchEntry? = stateQueue.sync {
      guard let entry = entriesByPatternID.removeValue(forKey: patternID) else { return nil }
      watcherIdentifiers.removeValue(forKey: ObjectIdentifier(entry.watcher))
      lastAnimationTimestamps.removeValue(forKey: patternID)
      if currentAnimation?.patternID == patternID {
        currentAnimation = nil
      }
      return entry
    }

    entry?.watcher.stop()
  }

  private func hasWatcher(for patternID: UUID) -> Bool {
    stateQueue.sync { entriesByPatternID[patternID] != nil }
  }

  private func patternID(for watcher: FileWatching) -> UUID? {
    stateQueue.sync { watcherIdentifiers[ObjectIdentifier(watcher)] }
  }

  private func context(for patternID: UUID) -> WatchContext? {
    stateQueue.sync { entriesByPatternID[patternID]?.context }
  }

  private func updateLineCount(for patternID: UUID, count: Int) {
    stateQueue.sync {
      guard var entry = entriesByPatternID[patternID] else { return }
      entry.context.lineCount = count
      entriesByPatternID[patternID] = entry
    }
  }

  private func pattern(for event: MatchEvent) -> LogPattern? {
    stateQueue.sync { entriesByPatternID[event.patternID]?.context.pattern }
  }

  private func priority(for patternID: UUID) -> Int {
    stateQueue.sync { patternPriorities[patternID] ?? Int.max }
  }

  @MainActor
  private func shouldTriggerAnimation(
    for patternID: UUID,
    priority: Int,
    timestamp: Date
  ) -> Bool {
    if iconAnimator.state == .idle {
      stateQueue.sync { currentAnimation = nil }
    }

    let lastForPattern = stateQueue.sync { lastAnimationTimestamps[patternID] }
    if let last = lastForPattern, timestamp.timeIntervalSince(last) < debounceInterval {
      return false
    }

    let current = stateQueue.sync { currentAnimation }
    guard let current else {
      return true
    }

    if priority < current.priority {
      return true
    }

    if current.patternID == patternID {
      return true
    }

    return iconAnimator.state == .idle
  }

  @MainActor
  private func recordAnimationStart(for patternID: UUID, priority: Int, timestamp: Date) {
    stateQueue.sync {
      currentAnimation = (patternID: patternID, priority: priority)
      lastAnimationTimestamps[patternID] = timestamp
    }
  }
}

// MARK: - FileWatcherDelegate

extension LogMonitor: FileWatcherDelegate {
  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
    guard
      !lines.isEmpty,
      let patternID = patternID(for: watcher),
      var context = context(for: patternID)
    else { return }

    var nextLineNumber = context.lineCount

    for line in lines {
      nextLineNumber += 1
      guard patternMatcher.match(line: line, pattern: context.pattern) != nil else { continue }

      let capturedLine = line
      let lineNumber = nextLineNumber
      let filePath = watcher.path

      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.handleMatch(
          patternID: patternID,
          line: capturedLine,
          lineNumber: lineNumber,
          filePath: filePath
        )
      }
    }

    updateLineCount(for: patternID, count: nextLineNumber)
  }

  func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError) {
    guard let patternID = patternID(for: watcher) else { return }
    removeWatcher(forPatternID: patternID)
  }
}

// MARK: - MatchEventHandlerDelegate

@MainActor
private extension LogMonitor {
  func handleMatch(
    patternID: UUID,
    line: String,
    lineNumber: Int,
    filePath: String
  ) {
    guard let pattern = pattern(forPatternID: patternID) else { return }
    let priorityValue = priority(for: patternID)

    matchEventHandler.handleMatch(
      pattern: pattern,
      line: line,
      lineNumber: lineNumber,
      filePath: filePath,
      priority: priorityValue
    )
  }

  func pattern(forPatternID patternID: UUID) -> LogPattern? {
    stateQueue.sync { entriesByPatternID[patternID]?.context.pattern }
  }
}

extension LogMonitor: MatchEventHandlerDelegate {
  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
    guard let pattern = pattern(for: event) else { return }
    let timestamp = dateProvider()
    guard shouldTriggerAnimation(for: event.patternID, priority: event.priority, timestamp: timestamp) else {
      return
    }
    iconAnimator.startAnimation(style: pattern.animationStyle, color: pattern.color)
    recordAnimationStart(for: event.patternID, priority: event.priority, timestamp: timestamp)
  }

  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
    onHistoryUpdate?(historyDidUpdate)
  }
}

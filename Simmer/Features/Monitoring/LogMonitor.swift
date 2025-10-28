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

  private struct WatchContext {
    var pattern: LogPattern
    var lineCount: Int
  }

  private let configurationStore: ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let watcherFactory: WatcherFactory
  private let stateQueue = DispatchQueue(label: "com.quantierra.Simmer.log-monitor")
  private let logger = OSLog(subsystem: "com.quantierra.Simmer", category: "LogMonitor")

  private var watchers: [ObjectIdentifier: FileWatching] = [:]
  private var contexts: [ObjectIdentifier: WatchContext] = [:]
  private var patternIdentifiers: [UUID: ObjectIdentifier] = [:]

  init(
    configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
    patternMatcher: PatternMatcherProtocol = RegexPatternMatcher(),
    matchEventHandler: MatchEventHandler,
    iconAnimator: IconAnimator,
    watcherFactory: @escaping WatcherFactory = { pattern in
      FileWatcher(path: pattern.logPath)
    }
  ) {
    self.configurationStore = configurationStore
    self.patternMatcher = patternMatcher
    self.matchEventHandler = matchEventHandler
    self.iconAnimator = iconAnimator
    self.watcherFactory = watcherFactory
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
      let current = Array(watchers.values)
      watchers.removeAll()
      contexts.removeAll()
      patternIdentifiers.removeAll()
      return current
    }

    activeWatchers.forEach { $0.stop() }
  }

  private func configureWatchers(for patterns: [LogPattern]) {
    let identifiersToRemove: [ObjectIdentifier] = stateQueue.sync {
      let existingIdentifiers = Set(patternIdentifiers.values)
      let incoming = Set(patterns.map { patternIdentifiers[$0.id] }.compactMap { $0 })
      return Array(existingIdentifiers.subtracting(incoming))
    }

    identifiersToRemove.forEach { removeWatcher(forIdentifier: $0) }

    for pattern in patterns {
      if hasWatcher(for: pattern.id) {
        updatePattern(pattern)
      } else {
        addWatcher(for: pattern)
      }
    }
  }

  private func addWatcher(for pattern: LogPattern) {
    let watcher = watcherFactory(pattern)
    watcher.delegate = self
    let identifier = ObjectIdentifier(watcher)

    stateQueue.sync {
      watchers[identifier] = watcher
      contexts[identifier] = WatchContext(pattern: pattern, lineCount: 0)
      patternIdentifiers[pattern.id] = identifier
    }

    do {
      try watcher.start()
    } catch {
      // Cleanup on failure so future attempts can retry.
      os_log(.error, log: logger, "Failed to start watcher for pattern '%{public}@' at path '%{public}@': %{public}@",
             pattern.name, pattern.logPath, String(describing: error))
      removeWatcher(forIdentifier: identifier)
    }
  }

  private func updatePattern(_ pattern: LogPattern) {
    stateQueue.sync {
      guard let identifier = patternIdentifiers[pattern.id] else { return }
      if var context = contexts[identifier] {
        context.pattern = pattern
        contexts[identifier] = context
      }
    }
  }

  private func removeWatcher(forIdentifier identifier: ObjectIdentifier) {
    let watcher = stateQueue.sync { watchers.removeValue(forKey: identifier) }
    watcher?.stop()

    stateQueue.sync {
      contexts.removeValue(forKey: identifier)
      if let entry = patternIdentifiers.first(where: { $0.value == identifier }) {
        patternIdentifiers.removeValue(forKey: entry.key)
      }
    }
  }

  private func hasWatcher(for patternID: UUID) -> Bool {
    stateQueue.sync { patternIdentifiers[patternID] != nil }
  }

  private func context(for watcher: FileWatching) -> WatchContext? {
    stateQueue.sync { contexts[ObjectIdentifier(watcher)] }
  }

  private func updateLineCount(for watcher: FileWatching, count: Int) {
    stateQueue.sync {
      let identifier = ObjectIdentifier(watcher)
      guard var context = contexts[identifier] else { return }
      context.lineCount = count
      contexts[identifier] = context
    }
  }

  private func pattern(for event: MatchEvent) -> LogPattern? {
    stateQueue.sync {
      guard let identifier = patternIdentifiers[event.patternID],
            let context = contexts[identifier] else {
        return nil
      }
      return context.pattern
    }
  }
}

// MARK: - FileWatcherDelegate

extension LogMonitor: FileWatcherDelegate {
  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
    guard var context = context(for: watcher), !lines.isEmpty else { return }

    var nextLineNumber = context.lineCount

    for line in lines {
      nextLineNumber += 1
      guard patternMatcher.match(line: line, pattern: context.pattern) != nil else { continue }

      let pattern = context.pattern
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.matchEventHandler.handleMatch(
          pattern: pattern,
          line: line,
          lineNumber: nextLineNumber,
          filePath: watcher.path
        )
      }
    }

    updateLineCount(for: watcher, count: nextLineNumber)
  }

  func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError) {
    removeWatcher(forIdentifier: ObjectIdentifier(watcher))
  }
}

// MARK: - MatchEventHandlerDelegate

extension LogMonitor: MatchEventHandlerDelegate {
  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
    guard let pattern = pattern(for: event) else { return }
    iconAnimator.startAnimation(style: pattern.animationStyle, color: pattern.color)
  }

  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
    onHistoryUpdate?(historyDidUpdate)
  }
}

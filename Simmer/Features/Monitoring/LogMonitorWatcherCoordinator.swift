//
//  LogMonitorWatcherCoordinator.swift
//  Simmer
//
//  Manages watcher lifecycle for ``LogMonitor``.
//

import Foundation
import os.log

@MainActor
internal final class LogMonitorWatcherCoordinator {
  private let stateStore: LogMonitorStateStore
  private let patternValidator: LogMonitorPatternAccessValidator
  private let watcherFactory: LogMonitor.WatcherFactory
  private let alertPresenter: LogMonitorAlertPresenting
  private let logger: OSLog
  private let maxWatcherCount: Int
  private var didWarnAboutPatternLimit = false

  init(
    stateStore: LogMonitorStateStore,
    patternValidator: LogMonitorPatternAccessValidator,
    watcherFactory: @escaping LogMonitor.WatcherFactory,
    alertPresenter: LogMonitorAlertPresenting,
    logger: OSLog,
    maxWatcherCount: Int
  ) {
    self.stateStore = stateStore
    self.patternValidator = patternValidator
    self.watcherFactory = watcherFactory
    self.alertPresenter = alertPresenter
    self.logger = logger
    self.maxWatcherCount = maxWatcherCount
  }

  func configureWatchers(
    for patterns: [LogPattern],
    onRead: @escaping (FileWatching, [String]) -> Void,
    onError: @escaping (FileWatching, FileWatcherError) -> Void
  ) {
    let limitedPatterns = Array(preparedPatterns(from: patterns).prefix(maxWatcherCount))
    let priorities = Dictionary(uniqueKeysWithValues: limitedPatterns.enumerated().map { ($1.id, $0) })
    stateStore.storePriorities(priorities)

    let staleIDs = stateStore.patternIDsToRemove(keeping: limitedPatterns.map(\.id))
    staleIDs.forEach { removeWatcher(for: $0)?.watcher.stop() }

    for pattern in limitedPatterns {
      if updateWatcher(with: pattern, onRead: onRead, onError: onError) { continue }
      addWatcher(for: pattern, onRead: onRead, onError: onError)
    }

    if patterns.count > maxWatcherCount {
      presentPatternLimitAlert(totalPatternCount: patterns.count)
    } else {
      didWarnAboutPatternLimit = false
    }
  }

  func removeWatcher(for patternID: UUID) -> LogMonitorStateStore.WatchEntry? {
    stateStore.removeWatcher(for: patternID)
  }

  func removeAllWatchers() -> [FileWatching] {
    didWarnAboutPatternLimit = false
    return stateStore.removeAllWatchers()
  }

  private func preparedPatterns(from patterns: [LogPattern]) -> [LogPattern] {
    patterns.compactMap { patternValidator.validateAccess(for: $0).pattern }
  }

  private func addWatcher(
    for pattern: LogPattern,
    onRead: @escaping (FileWatching, [String]) -> Void,
    onError: @escaping (FileWatching, FileWatcherError) -> Void
  ) {
    let watcher = watcherFactory(pattern)
    let delegate = LogMonitorFileWatcherBridge(onRead: onRead, onError: onError)

    guard stateStore.storeWatcher(
      watcher,
      delegate: delegate,
      for: pattern,
      maximumCount: maxWatcherCount
    ) else {
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
      stateStore.removeWatcher(for: pattern.id)?.watcher.stop()
    }
  }

  private func updateWatcher(
    with pattern: LogPattern,
    onRead: @escaping (FileWatching, [String]) -> Void,
    onError: @escaping (FileWatching, FileWatcherError) -> Void
  ) -> Bool {
    guard stateStore.updatePattern(pattern) else { return false }
    removeWatcher(for: pattern.id)?.watcher.stop()
    addWatcher(for: pattern, onRead: onRead, onError: onError)
    return true
  }

  private func presentPatternLimitAlert(totalPatternCount: Int) {
    guard !didWarnAboutPatternLimit else { return }
    didWarnAboutPatternLimit = true
    let droppedCount = totalPatternCount - maxWatcherCount
    let patternWord = droppedCount == 1 ? "pattern was" : "patterns were"
    alertPresenter.presentAlert(
      title: "Pattern limit reached",
      message: """
      Simmer can monitor up to \(maxWatcherCount) patterns at a time.
      \(droppedCount) \(patternWord) left inactive after the latest import.
      Remove or disable patterns in Settings to resume monitoring.
      """
    )
  }
}

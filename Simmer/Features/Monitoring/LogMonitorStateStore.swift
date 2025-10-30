//
//  LogMonitorStateStore.swift
//  Simmer
//
//  Encapsulates mutable watcher state for ``LogMonitor`` behind a serial queue.
//

import Foundation

internal final class LogMonitorStateStore {
  internal struct WatchContext {
    var pattern: LogPattern
    var lineCount: Int
  }

  internal struct WatchEntry {
    var watcher: FileWatching
    var context: WatchContext
    var delegate: FileWatcherDelegate
  }

  private let queue: DispatchQueue
  private var entriesByPatternID: [UUID: WatchEntry] = [:]
  private var watcherIdentifiers: [ObjectIdentifier: UUID] = [:]
  private var patternPriorities: [UUID: Int] = [:]
  private var suppressedAlertPatternIDs: Set<UUID> = []

  init(queueLabel: String) {
    self.queue = DispatchQueue(label: queueLabel)
  }

  func removeAllWatchers() -> [FileWatching] {
    queue.sync {
      let watchers = entriesByPatternID.values.map(\.watcher)
      entriesByPatternID.removeAll()
      watcherIdentifiers.removeAll()
      patternPriorities.removeAll()
      suppressedAlertPatternIDs.removeAll()
      return watchers
    }
  }

  func storePriorities(_ priorities: [UUID: Int]) {
    queue.sync {
      patternPriorities = priorities
    }
  }

  func patternIDsToRemove(keeping patternIDs: [UUID]) -> [UUID] {
    queue.sync {
      let existingIDs = Set(entriesByPatternID.keys)
      let incomingIDs = Set(patternIDs)
      return Array(existingIDs.subtracting(incomingIDs))
    }
  }

  func storeWatcher(
    _ watcher: FileWatching,
    delegate: FileWatcherDelegate,
    for pattern: LogPattern,
    maximumCount: Int
  ) -> Bool {
    queue.sync {
      guard entriesByPatternID.count < maximumCount else { return false }
      watcher.delegate = delegate
      let context = WatchContext(pattern: pattern, lineCount: 0)
      let entry = WatchEntry(watcher: watcher, context: context, delegate: delegate)
      entriesByPatternID[pattern.id] = entry
      watcherIdentifiers[ObjectIdentifier(watcher)] = pattern.id
      return true
    }
  }

  func updatePattern(_ pattern: LogPattern) -> Bool {
    queue.sync {
      guard var entry = entriesByPatternID[pattern.id] else { return false }
      let needsRestart = entry.context.pattern.logPath != pattern.logPath
      entry.context.pattern = pattern
      entriesByPatternID[pattern.id] = entry
      return needsRestart
    }
  }

  func removeWatcher(for patternID: UUID) -> WatchEntry? {
    queue.sync {
      guard let entry = entriesByPatternID.removeValue(forKey: patternID) else {
        return nil
      }
      watcherIdentifiers.removeValue(forKey: ObjectIdentifier(entry.watcher))
      return entry
    }
  }

  func hasWatcher(for patternID: UUID) -> Bool {
    queue.sync { entriesByPatternID[patternID] != nil }
  }

  func patternID(for watcher: FileWatching) -> UUID? {
    queue.sync { watcherIdentifiers[ObjectIdentifier(watcher)] }
  }

  func context(for patternID: UUID) -> WatchContext? {
    queue.sync { entriesByPatternID[patternID]?.context }
  }

  func updateLineCount(for patternID: UUID, to newValue: Int) {
    queue.sync {
      guard var entry = entriesByPatternID[patternID] else { return }
      entry.context.lineCount = newValue
      entriesByPatternID[patternID] = entry
    }
  }

  func pattern(for patternID: UUID) -> LogPattern? {
    queue.sync { entriesByPatternID[patternID]?.context.pattern }
  }

  func priority(for patternID: UUID) -> Int {
    queue.sync { patternPriorities[patternID] ?? Int.max }
  }

  func suppressAlerts(for patternID: UUID) {
    queue.sync {
      suppressedAlertPatternIDs.insert(patternID)
    }
  }

  func unsuppressAlerts(for patternID: UUID) {
    queue.sync {
      suppressedAlertPatternIDs.remove(patternID)
    }
  }

  func isAlertSuppressed(for patternID: UUID) -> Bool {
    queue.sync { suppressedAlertPatternIDs.contains(patternID) }
  }
}

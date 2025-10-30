//
//  LogMonitorFileWatcherBridge.swift
//  Simmer
//
//  Routes file watcher callbacks through lightweight closures.
//

import Foundation

internal final class LogMonitorFileWatcherBridge: FileWatcherDelegate {
  private let onRead: (FileWatching, [String]) -> Void
  private let onError: (FileWatching, FileWatcherError) -> Void

  init(
    onRead: @escaping (FileWatching, [String]) -> Void,
    onError: @escaping (FileWatching, FileWatcherError) -> Void
  ) {
    self.onRead = onRead
    self.onError = onError
  }

  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
    onRead(watcher, lines)
  }

  func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError) {
    onError(watcher, error)
  }
}

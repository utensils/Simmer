//
//  FileWatcherDelegate.swift
//  Simmer
//
//  Delegate notifications for file watcher events.
//

import Foundation

internal protocol FileWatching: AnyObject {
  var path: String { get }
  var delegate: FileWatcherDelegate? { get set }
  func start() throws
  func stop()
}

internal protocol FileWatcherDelegate: AnyObject {
  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String])
  func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError)
}

internal enum FileWatcherError: Error, Equatable {
  case fileDeleted(path: String)
  case permissionDenied(path: String)
  case fileDescriptorInvalid
}

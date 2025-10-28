//
//  FileWatcherDelegate.swift
//  Simmer
//
//  Delegate notifications for file watcher events.
//

import Foundation

protocol FileWatcherDelegate: AnyObject {
  func fileWatcher(_ watcher: FileWatcher, didReadLines lines: [String])
  func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcherError)
}

enum FileWatcherError: Error, Equatable {
  case fileDeleted(path: String)
  case permissionDenied(path: String)
  case fileDescriptorInvalid
}

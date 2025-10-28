//
//  FileWatcherDelegate.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Callback protocol for FileWatcher to notify LogMonitor of file events
/// Per contracts/internal-protocols.md
protocol FileWatcherDelegate: AnyObject {
    /// Called when new content appended to watched file
    func fileWatcher(_ watcher: FileWatcher, didReadLines lines: [String])

    /// Called when file becomes inaccessible (deleted, permissions changed)
    func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcherError)
}

enum FileWatcherError: Error {
    case fileDeleted(path: String)
    case permissionDenied(path: String)
    case fileDescriptorInvalid
}

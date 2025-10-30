//
//  LogMonitorWatcherHandlerFactory.swift
//  Simmer
//
//  Builds file watcher handlers for ``LogMonitor``.
//

import Foundation

internal struct LogMonitorWatcherHandlerFactory {
  let stateStore: LogMonitorStateStore
  let processingQueue: DispatchQueue
  let matchContextBuilder: (UUID) -> LogMonitorMatchContext?
  let errorContextBuilder: () -> LogMonitorWatcherErrorContext?

  func makeHandlers() -> (
    onRead: (FileWatching, [String]) -> Void,
    onError: (FileWatching, FileWatcherError) -> Void
  ) {
    let onRead: (FileWatching, [String]) -> Void = { watcher, lines in
      guard
        !lines.isEmpty,
        let patternID = stateStore.patternID(for: watcher),
        let context = matchContextBuilder(patternID)
      else { return }

      processingQueue.async {
        LogMonitorMatchProcessor.process(
          lines: lines,
          patternID: patternID,
          filePath: watcher.path,
          context: context
        )
      }
    }

    let onError: (FileWatching, FileWatcherError) -> Void = { watcher, error in
      guard
        let patternID = stateStore.patternID(for: watcher),
        let context = errorContextBuilder()
      else { return }

      processingQueue.async {
        Task { @MainActor in
          LogMonitorWatcherErrorHandler.handleError(
            patternID: patternID,
            error: error,
            filePath: watcher.path,
            context: context
          )
        }
      }
    }

    return (onRead, onError)
  }
}

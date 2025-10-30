//
//  LogMonitorWatcherErrorHandler.swift
//  Simmer
//
//  Centralises watcher error handling for ``LogMonitor``.
//

import Foundation
import os.log

internal struct LogMonitorWatcherErrorContext {
  let stateStore: LogMonitorStateStore
  let patternValidator: LogMonitorPatternAccessValidator
  let alertPresenter: LogMonitorAlertPresenting
  let logger: OSLog
  let removeWatcher: (UUID) -> LogMonitorStateStore.WatchEntry?
  let reloadPatterns: @MainActor () -> Void
}

internal enum LogMonitorWatcherErrorHandler {
  static func handleError(
    patternID: UUID,
    error: FileWatcherError,
    filePath: String,
    context: LogMonitorWatcherErrorContext
  ) {
    if context.stateStore.isAlertSuppressed(for: patternID) {
      context.removeWatcher(patternID)?.watcher.stop()
      return
    }

    guard let entry = context.removeWatcher(patternID) else { return }
    entry.watcher.stop()
    let pattern = entry.context.pattern

    os_log(
      .error,
      log: context.logger,
      "Watcher error for pattern '%{public}@' at path '%{public}@': %{public}@",
      pattern.name,
      pattern.logPath,
      String(describing: error)
    )

    Task { @MainActor in
      context.patternValidator.disableAfterWatcherError(pattern)
      let message = context.patternValidator.alertMessage(
        for: error,
        patternName: pattern.name,
        filePath: filePath
      )
      context.alertPresenter.presentAlert(
        title: "Monitoring paused for \(pattern.name)",
        message: message
      )
      context.reloadPatterns()
    }
  }
}

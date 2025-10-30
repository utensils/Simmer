//
//  LogMonitorPatternAccessValidator.swift
//  Simmer
//
//  Validates manual file access for monitoring patterns and handles disable flows.
//

import Foundation
import os.log

internal struct PatternValidationOutcome {
  let pattern: LogPattern?
  let didChangeConfiguration: Bool
}

internal final class LogMonitorPatternAccessValidator {
  private let configurationStore: ConfigurationStoreProtocol
  private let alertPresenter: LogMonitorAlertPresenting
  private let logger: OSLog
  private let notifyPatternsDidChange: @MainActor () -> Void

  init(
    configurationStore: ConfigurationStoreProtocol,
    alertPresenter: LogMonitorAlertPresenting,
    logger: OSLog,
    notifyPatternsDidChange: @escaping @MainActor () -> Void
  ) {
    self.configurationStore = configurationStore
    self.alertPresenter = alertPresenter
    self.logger = logger
    self.notifyPatternsDidChange = notifyPatternsDidChange
  }

  @MainActor
  // swiftlint:disable function_body_length
  func validateAccess(for pattern: LogPattern) -> PatternValidationOutcome {
    var updatedPattern = pattern
    let expandedPath = PathExpander.expand(pattern.logPath)
    var didChangeConfiguration = false

    if expandedPath != pattern.logPath {
      updatedPattern.logPath = expandedPath
      do {
        try configurationStore.updatePattern(updatedPattern)
        didChangeConfiguration = true
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to persist expanded path '%{public}@' for pattern '%{public}@': %{public}@",
          expandedPath,
          pattern.name,
          String(describing: error)
        )
      }
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
      disable(
        pattern: updatedPattern,
        message: """
        Simmer cannot find "\(expandedPath)". Verify the file exists, then re-enable
        "\(updatedPattern.name)" in Settings.
        """
      )
      return PatternValidationOutcome(pattern: nil, didChangeConfiguration: true)
    }

    if isDirectory.boolValue {
      disable(
        pattern: updatedPattern,
        message: """
        Simmer can only monitor files. Select a log file instead of "\(expandedPath)" before
        re-enabling "\(updatedPattern.name)".
        """
      )
      return PatternValidationOutcome(pattern: nil, didChangeConfiguration: true)
    }

    guard fileManager.isReadableFile(atPath: expandedPath) else {
      disable(
        pattern: updatedPattern,
        message: """
        Simmer cannot read "\(expandedPath)". Check file permissions, then re-enable
        "\(updatedPattern.name)" in Settings.
        """
      )
      return PatternValidationOutcome(pattern: nil, didChangeConfiguration: true)
    }

    return PatternValidationOutcome(
      pattern: updatedPattern,
      didChangeConfiguration: didChangeConfiguration
    )
  }
  // swiftlint:enable function_body_length

  func alertMessage(
    for error: FileWatcherError,
    patternName: String,
    filePath: String
  ) -> String {
    switch error {
    case .fileDeleted:
      return """
      Simmer stopped monitoring "\(patternName)" because "\(filePath)" is missing. Restore the
      file or choose a new path in Settings, then re-enable the pattern.
      """

    case .permissionDenied:
      return """
      Simmer no longer has permission to read "\(filePath)" for pattern "\(patternName)". Update
      permissions or choose a new file in Settings before re-enabling the pattern.
      """

    case .fileDescriptorInvalid:
      return """
      Simmer hit an unexpected error while reading "\(filePath)" for pattern "\(patternName)".
      Verify the file is accessible and re-enable the pattern in Settings.
      """
    }
  }

  @MainActor
  func disableAfterWatcherError(_ pattern: LogPattern) {
    guard pattern.enabled else { return }
    var updatedPattern = pattern
    updatedPattern.enabled = false
    do {
      try configurationStore.updatePattern(updatedPattern)
      notifyPatternsDidChange()
    } catch {
      os_log(
        .error,
        log: logger,
        "Failed to disable pattern '%{public}@' after watcher error: %{public}@",
        pattern.name,
        String(describing: error)
      )
    }
  }

  @MainActor
  private func disable(pattern: LogPattern, message: String) {
    var updatedPattern = pattern
    if updatedPattern.enabled {
      updatedPattern.enabled = false
      do {
        try configurationStore.updatePattern(updatedPattern)
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to disable pattern '%{public}@' after access error: %{public}@",
          pattern.name,
          String(describing: error)
        )
      }
    }

    alertPresenter.presentAlert(
      title: "File access required",
      message: message
    )

    notifyPatternsDidChange()
  }
}

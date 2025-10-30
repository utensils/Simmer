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
  private let fileAccessManager: FileAccessManaging

  @MainActor
  init(
    configurationStore: ConfigurationStoreProtocol,
    alertPresenter: LogMonitorAlertPresenting,
    logger: OSLog,
    notifyPatternsDidChange: @escaping @MainActor () -> Void,
    fileAccessManager: FileAccessManaging? = nil
  ) {
    self.configurationStore = configurationStore
    self.alertPresenter = alertPresenter
    self.logger = logger
    self.notifyPatternsDidChange = notifyPatternsDidChange
    self.fileAccessManager = fileAccessManager ?? FileAccessManager()
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
      return handleMissingFile(
        pattern: updatedPattern,
        missingPath: expandedPath
      )
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
}

// MARK: - Missing File Handling

private extension LogMonitorPatternAccessValidator {
  @MainActor
  func handleMissingFile(
    pattern: LogPattern,
    missingPath: String
  ) -> PatternValidationOutcome {
    while true {
      let action = alertPresenter.presentMissingFilePrompt(
        patternName: pattern.name,
        missingPath: missingPath
      )

      switch action {
      case .locate:
        if let outcome = processLocateAction(for: pattern) {
          return outcome
        }

      case .disable, .cancel:
        disable(pattern: pattern, message: nil)
        return PatternValidationOutcome(pattern: nil, didChangeConfiguration: true)
      }
    }
  }

  @MainActor
  func processLocateAction(for pattern: LogPattern) -> PatternValidationOutcome? {
    do {
      let url = try fileAccessManager.requestAccess(allowedFileTypes: nil)
      let newPath = PathExpander.expand(url.path)
      let (updatedPattern, didChange) = persistUpdatedPath(
        for: pattern,
        newPath: newPath
      )
      notifyPatternsDidChange()
      return PatternValidationOutcome(
        pattern: updatedPattern,
        didChangeConfiguration: didChange
      )
    } catch let accessError as FileAccessError {
      presentLocateError(for: accessError)
      return nil
    } catch {
      alertPresenter.presentAlert(
        title: "Unable to read file",
        message: "Simmer failed to open the selected file. Choose a different file and try again."
      )
      return nil
    }
  }

  @MainActor
  func persistUpdatedPath(
    for pattern: LogPattern,
    newPath: String
  ) -> (LogPattern, Bool) {
    var updatedPattern = pattern
    let didChange = newPath != pattern.logPath
    guard didChange else { return (pattern, false) }

    updatedPattern.logPath = newPath
    do {
      try configurationStore.updatePattern(updatedPattern)
    } catch {
      os_log(
        .error,
        log: logger,
        "Failed to update pattern '%{public}@' with new path '%{public}@': %{public}@",
        pattern.name,
        newPath,
        String(describing: error)
      )
    }
    return (updatedPattern, true)
  }

  @MainActor
  func presentLocateError(for error: FileAccessError) {
    switch error {
    case .userCancelled:
      break
    case .fileNotAccessible(let path):
      alertPresenter.presentAlert(
        title: "Unable to read file",
        message: """
        Simmer cannot read "\(path)". Choose a different file to continue monitoring.
        """
      )
    }
  }

  @MainActor
  func disable(
    pattern: LogPattern,
    message: String?,
    alertTitle: String = "File access required"
  ) {
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

    if let message {
      alertPresenter.presentAlert(
        title: alertTitle,
        message: message
      )
    }

    notifyPatternsDidChange()
  }
}

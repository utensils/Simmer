//
//  LogMonitorAlertPresenter.swift
//  Simmer
//
//  Provides main-thread alert presentation for monitoring errors.
//

import AppKit

internal enum MissingFileAlertAction {
  case locate
  case disable
  case cancel
}

internal protocol LogMonitorAlertPresenting: AnyObject {
  @MainActor
  func presentAlert(title: String, message: String)

  @MainActor
  func presentMissingFilePrompt(patternName: String, missingPath: String) -> MissingFileAlertAction
}

internal final class NSAlertPresenter: LogMonitorAlertPresenting {
  @MainActor
  func presentAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  @MainActor
  func presentMissingFilePrompt(
    patternName: String,
    missingPath: String
  ) -> MissingFileAlertAction {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Locate Missing Log File"
    let displayPath = (missingPath as NSString).abbreviatingWithTildeInPath
    alert.informativeText = """
    Simmer can no longer find "\(displayPath)" for pattern "\(patternName)". Locate the file to \
    continue monitoring or keep the pattern disabled for now.
    """
    alert.icon = NSImage(named: NSImage.cautionName)

    alert.addButton(withTitle: "Locate…")
    let keepDisabledButton = alert.addButton(withTitle: "Keep Disabled")
    keepDisabledButton.keyEquivalent = "\u{1b}"

    switch alert.runModal() {
    case .alertFirstButtonReturn:
      return .locate
    case .alertSecondButtonReturn:
      return .disable
    default:
      return .cancel
    }
  }
}

internal final class SilentAlertPresenter: LogMonitorAlertPresenting {
  @MainActor
  func presentAlert(title: String, message: String) {}

  @MainActor
  func presentMissingFilePrompt(
    patternName: String,
    missingPath: String
  ) -> MissingFileAlertAction {
    .cancel
  }
}

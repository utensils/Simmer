//
//  LogMonitorAlertPresenter.swift
//  Simmer
//
//  Provides main-thread alert presentation for monitoring errors.
//

import AppKit

internal protocol NSApplicationActivating: AnyObject {
  func activate(ignoringOtherApps flag: Bool)
}

extension NSApplication: NSApplicationActivating {}

internal protocol AlertButtonHandling: AnyObject {
  var keyEquivalent: String { get set }
}

extension NSButton: AlertButtonHandling {}

internal protocol AlertPrompting: AnyObject {
  var alertStyle: NSAlert.Style { get set }
  var messageText: String { get set }
  var informativeText: String { get set }
  var icon: NSImage? { get set }

  @discardableResult
  func addButton(withTitle title: String) -> AlertButtonHandling
  func runModal() -> NSApplication.ModalResponse
}

internal final class NSAlertPrompt: AlertPrompting {
  private var alert: NSAlert

  init(alert: NSAlert = NSAlert()) {
    self.alert = alert
  }

  var alertStyle: NSAlert.Style {
    get { alert.alertStyle }
    set { alert.alertStyle = newValue }
  }

  var messageText: String {
    get { alert.messageText }
    set { alert.messageText = newValue }
  }

  var informativeText: String {
    get { alert.informativeText }
    set { alert.informativeText = newValue }
  }

  var icon: NSImage? {
    get { alert.icon }
    set { alert.icon = newValue }
  }

  @discardableResult
  func addButton(withTitle title: String) -> AlertButtonHandling {
    return alert.addButton(withTitle: title)
  }

  func runModal() -> NSApplication.ModalResponse {
    alert.runModal()
  }
}

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
  private let alertFactory: @MainActor () -> AlertPrompting
  private weak var application: NSApplicationActivating?

  @MainActor
  init(
    alertFactory: @escaping @MainActor () -> AlertPrompting = { NSAlertPrompt() },
    application: NSApplicationActivating? = NSApp
  ) {
    self.alertFactory = alertFactory
    self.application = application
  }

  @MainActor
  func presentAlert(title: String, message: String) {
    let alert = alertFactory()
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
    MissingFilePromptRunner.present(
      application: application,
      prompt: alertFactory(),
      patternName: patternName,
      missingPath: missingPath
    )
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

// MARK: - Prompt Coordination

internal enum MissingFilePromptRunner {
  @MainActor
  static func present(
    application: NSApplicationActivating?,
    prompt: AlertPrompting,
    patternName: String,
    missingPath: String
  ) -> MissingFileAlertAction {
    application?.activate(ignoringOtherApps: true)
    prompt.alertStyle = .warning
    prompt.messageText = "Locate Missing Log File"
    let displayPath = (missingPath as NSString).abbreviatingWithTildeInPath
    prompt.informativeText = """
    Simmer can no longer find "\(displayPath)" for pattern "\(patternName)". Locate the file to \
    continue monitoring or keep the pattern disabled for now.
    """
    prompt.icon = NSImage(named: NSImage.cautionName)

    prompt.addButton(withTitle: "Locate…")
    let keepDisabledButton = prompt.addButton(withTitle: "Keep Disabled")
    keepDisabledButton.keyEquivalent = "\u{1b}"

    switch prompt.runModal() {
    case .alertFirstButtonReturn:
      return .locate
    case .alertSecondButtonReturn:
      return .disable
    default:
      return .cancel
    }
  }
}

//
//  LogMonitorAlertPresenter.swift
//  Simmer
//
//  Provides main-thread alert presentation for monitoring errors.
//

import AppKit

internal protocol LogMonitorAlertPresenting: AnyObject {
  @MainActor
  func presentAlert(title: String, message: String)
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
}

internal final class SilentAlertPresenter: LogMonitorAlertPresenting {
  @MainActor
  func presentAlert(title: String, message: String) {}
}

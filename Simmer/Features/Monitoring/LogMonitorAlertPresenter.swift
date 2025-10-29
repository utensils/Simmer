//
//  LogMonitorAlertPresenter.swift
//  Simmer
//
//  Provides main-thread alert presentation for monitoring errors.
//

import AppKit

protocol LogMonitorAlertPresenting: AnyObject {
  @MainActor
  func presentAlert(title: String, message: String)
}

final class NSAlertPresenter: LogMonitorAlertPresenting {
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

final class SilentAlertPresenter: LogMonitorAlertPresenting {
  @MainActor
  func presentAlert(title: String, message: String) {}
}

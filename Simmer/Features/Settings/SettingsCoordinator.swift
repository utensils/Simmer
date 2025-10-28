//
//  SettingsCoordinator.swift
//  Simmer
//
//  Presents the SwiftUI-based settings window.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsCoordinator: NSObject, NSWindowDelegate {
  private let configurationStore: any ConfigurationStoreProtocol
  private let logMonitor: LogMonitor?

  private(set) var windowController: NSWindowController?
  private var previousActivationPolicy: NSApplication.ActivationPolicy?
  private var managesActivationPolicy = false

  init(
    configurationStore: any ConfigurationStoreProtocol,
    logMonitor: LogMonitor?
  ) {
    self.configurationStore = configurationStore
    self.logMonitor = logMonitor
  }

  func show() {
    prepareActivationPolicyIfNeeded()

    if let controller = windowController {
      controller.window?.orderFrontRegardless()
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let view = PatternListView(
      store: configurationStore,
      logMonitor: logMonitor
    )
    let hostingController = NSHostingController(rootView: view)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Simmer Settings"
    window.center()
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
    window.contentViewController = hostingController
    window.delegate = self

    let controller = NSWindowController(window: window)
    controller.shouldCascadeWindows = true
    controller.showWindow(nil)
    windowController = controller

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - NSWindowDelegate

  func windowWillClose(_ notification: Notification) {
    if let window = notification.object as? NSWindow,
       windowController?.window == window {
      windowController = nil
      restoreActivationPolicyIfNeeded()
    }
  }

  // MARK: - Activation Policy Management

  private func prepareActivationPolicyIfNeeded() {
    let app = NSApplication.shared
    guard app.activationPolicy != .regular else { return }

    previousActivationPolicy = app.activationPolicy
    managesActivationPolicy = true
    app.setActivationPolicy(.regular)
  }

  private func restoreActivationPolicyIfNeeded() {
    guard managesActivationPolicy, let previous = previousActivationPolicy else { return }
    NSApplication.shared.setActivationPolicy(previous)
    managesActivationPolicy = false
    previousActivationPolicy = nil
  }
}

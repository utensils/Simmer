//
//  SettingsCoordinator.swift
//  Simmer
//
//  Presents the SwiftUI-based settings window.
//

import AppKit
import SwiftUI

@MainActor
internal final class SettingsCoordinator: NSObject, NSWindowDelegate {
  private let configurationStore: any ConfigurationStoreProtocol
  private let logMonitor: LogMonitor?
  private let launchAtLoginController: LaunchAtLoginControlling
  private let defaultContentSize = NSSize(width: 800, height: 700)
  private let minimumContentSize = NSSize(width: 720, height: 600)

  private(set) var windowController: NSWindowController?
  private var previousActivationPolicy: NSApplication.ActivationPolicy?
  private var managesActivationPolicy = false

  internal init(
    configurationStore: any ConfigurationStoreProtocol,
    logMonitor: LogMonitor?,
    launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController()
  ) {
    self.configurationStore = configurationStore
    self.logMonitor = logMonitor
    self.launchAtLoginController = launchAtLoginController
  }

  func show() {
    NSLog("[SettingsCoordinator] show() invoked")
    prepareActivationPolicyIfNeeded()

    if let controller = windowController {
      reuseExistingWindow(controller)
      return
    }

    createAndShowNewWindow()
    NSLog("[SettingsCoordinator] window presented")
  }

  private func reuseExistingWindow(_ controller: NSWindowController) {
    NSLog("[SettingsCoordinator] reusing existing window")
    controller.window?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  private func createAndShowNewWindow() {
    let view = createPatternListView()
    let hostingController = createHostingController(with: view)
    let window = createWindow(with: hostingController)
    let controller = NSWindowController(window: window)
    controller.shouldCascadeWindows = true
    controller.showWindow(nil)
    window.contentMinSize = minimumContentSize
    windowController = controller
    presentWindow(window)
  }

  private func createPatternListView() -> PatternListView {
    PatternListView(
      store: configurationStore,
      logMonitor: logMonitor,
      launchAtLoginController: launchAtLoginController
    )
  }

  private func createHostingController(
    with view: PatternListView
  ) -> NSHostingController<PatternListView> {
    let controller = NSHostingController(rootView: view)
    controller.view.translatesAutoresizingMaskIntoConstraints = true
    controller.view.autoresizingMask = [.width, .height]
    controller.view.frame = NSRect(origin: .zero, size: defaultContentSize)
    return controller
  }

  private func createWindow(
    with hostingController: NSHostingController<PatternListView>
  ) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: defaultContentSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Simmer Settings"
    window.center()
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
    window.contentViewController = hostingController
    window.setContentSize(defaultContentSize)
    window.contentMinSize = minimumContentSize
    window.delegate = self
    return window
  }

  private func presentWindow(_ window: NSWindow) {
    window.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { [weak self, weak window] in
      guard
        let window,
        let minimumContentSize = self?.minimumContentSize
      else { return }
      window.contentMinSize = minimumContentSize
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - NSWindowDelegate

  func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
      windowController?.window == window
    else { return }

    windowController = nil
    restoreActivationPolicyIfNeeded()
  }

  func windowDidBecomeMain(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    window.contentMinSize = minimumContentSize
  }

  func windowDidResize(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    window.contentMinSize = minimumContentSize
  }

  func windowDidUpdate(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    window.contentMinSize = minimumContentSize
  }

  // MARK: - Activation Policy Management

  private func prepareActivationPolicyIfNeeded() {
    let app = NSApplication.shared
    let currentPolicy = app.activationPolicy()
    guard currentPolicy != .regular else { return }

    previousActivationPolicy = currentPolicy
    managesActivationPolicy = true
    app.setActivationPolicy(.regular)
  }

  private func restoreActivationPolicyIfNeeded() {
    guard managesActivationPolicy, let previous = previousActivationPolicy else { return }
    NSApplication.shared.setActivationPolicy(previous)
    managesActivationPolicy = false
    previousActivationPolicy = nil
  }

  // MARK: - Forced Dismissal

  func forceCloseWindow() {
    guard let controller = windowController, let window = controller.window else { return }

    for sheet in window.sheets {
      window.endSheet(sheet, returnCode: .cancel)
      sheet.close()
    }

    window.close()
  }
}

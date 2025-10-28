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
  private let logMonitor: LogMonitor

  private var windowController: NSWindowController?

  init(
    configurationStore: any ConfigurationStoreProtocol,
    logMonitor: LogMonitor
  ) {
    self.configurationStore = configurationStore
    self.logMonitor = logMonitor
  }

  func show() {
    // Temporarily switch to regular app to show window
    NSApp.setActivationPolicy(.regular)

    if let controller = windowController {
      controller.showWindow(nil)
      controller.window?.makeKeyAndOrderFront(nil)
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
    window.contentViewController = hostingController
    window.center()
    window.delegate = self

    let controller = NSWindowController(window: window)
    controller.shouldCascadeWindows = true
    controller.showWindow(nil)
    windowController = controller

    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - NSWindowDelegate

  func windowWillClose(_ notification: Notification) {
    if let window = notification.object as? NSWindow,
       windowController?.window == window {
      windowController = nil
      // Return to accessory mode when settings closes
      NSApp.setActivationPolicy(.accessory)
    }
  }
}

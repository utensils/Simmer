//
//  AppDelegate.swift
//  Simmer
//
//  Handles application lifecycle and bootstraps core services.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let configurationStore: any ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private var menuBuilder: MenuBuilder?
  private var settingsCoordinator: SettingsCoordinator?

  private var menuBarController: MenuBarController?
  private var logMonitor: LogMonitor?

  override init() {
    configurationStore = ConfigurationStore()
    patternMatcher = RegexPatternMatcher()
    matchEventHandler = MatchEventHandler()
    iconAnimator = IconAnimator()
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    let logMonitor = LogMonitor(
      configurationStore: configurationStore,
      patternMatcher: patternMatcher,
      matchEventHandler: matchEventHandler,
      iconAnimator: iconAnimator
    )
    self.logMonitor = logMonitor

    let settingsCoordinator = SettingsCoordinator(
      configurationStore: configurationStore,
      logMonitor: logMonitor
    )
    self.settingsCoordinator = settingsCoordinator

    let menuBuilder = MenuBuilder(
      matchEventHandler: matchEventHandler,
      settingsHandler: { [weak self] in
        self?.settingsCoordinator?.show()
      },
      quitHandler: {
        NSApplication.shared.terminate(nil)
      }
    )
    self.menuBuilder = menuBuilder

    let menuBarController = MenuBarController(
      statusBar: .system,
      iconAnimator: iconAnimator,
      menuBuilder: menuBuilder
    )
    self.menuBarController = menuBarController

    logMonitor.onHistoryUpdate = { [weak menuBarController] _ in
      menuBarController?.handleHistoryUpdate()
    }

    logMonitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    logMonitor?.stopAll()
  }
}

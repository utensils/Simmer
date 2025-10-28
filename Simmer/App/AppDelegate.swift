//
//  AppDelegate.swift
//  Simmer
//
//  Handles application lifecycle and bootstraps core services.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let configurationStore: ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator

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

    let menuBarController = MenuBarController(statusBar: .system, iconAnimator: iconAnimator)
    self.menuBarController = menuBarController

    let logMonitor = LogMonitor(
      configurationStore: configurationStore,
      patternMatcher: patternMatcher,
      matchEventHandler: matchEventHandler,
      iconAnimator: iconAnimator
    )
    self.logMonitor = logMonitor
    logMonitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    logMonitor?.stopAll()
  }
}

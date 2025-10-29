//
//  AppDelegate.swift
//  Simmer
//
//  Handles application lifecycle and bootstraps core services.
//

import AppKit
import os.log
import ServiceManagement

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
  private let launchLogger = OSLog(subsystem: "com.quantierra.Simmer", category: "LaunchAtLogin")

  override init() {
    configurationStore = ConfigurationStore()
    patternMatcher = RegexPatternMatcher()
    matchEventHandler = MatchEventHandler()
    iconAnimator = IconAnimator()
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let configurationPath = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]
    let environment = ProcessInfo.processInfo.environment
    let isRunningUnitTests = configurationPath?.contains("SimmerTests") == true
      || environment["XCInjectBundleInto"] != nil
    let isRunningUITests = configurationPath?.contains("SimmerUITests") == true
      || environment["XCTestBundleInjectPath"]?.contains("SimmerUITests") == true
    let shouldShowSettings = isRunningUITests
      || ProcessInfo.processInfo.environment["SIMMER_UI_TEST_SHOW_SETTINGS"] == "1"
      || CommandLine.arguments.contains("--show-settings")
    if shouldShowSettings {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }

    let isUsingXCTestRuntime = NSClassFromString("XCTestCase") != nil

    if isRunningUnitTests || (isUsingXCTestRuntime && !isRunningUITests) {
      return
    }

    let alertPresenter: LogMonitorAlertPresenting = isRunningUITests
      ? SilentAlertPresenter()
      : NSAlertPresenter()

    let logMonitor = LogMonitor(
      configurationStore: configurationStore,
      patternMatcher: patternMatcher,
      matchEventHandler: matchEventHandler,
      iconAnimator: iconAnimator,
      alertPresenter: alertPresenter
    )
    self.logMonitor = logMonitor

    let menuBuilder = MenuBuilder(
      matchEventHandler: matchEventHandler,
      settingsHandler: { [weak self] in
        self?.presentSettingsWindow()
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

    schedulePostLaunchTasks(isRunningUITests: isRunningUITests)

    if shouldShowSettings {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.presentSettingsWindow()
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    logMonitor?.stopAll()
  }

  private func schedulePostLaunchTasks(isRunningUITests: Bool) {
    guard let logMonitor else { return }

    DispatchQueue.main.async { [weak self, weak logMonitor] in
      logMonitor?.start()
      if !isRunningUITests {
        self?.configureLaunchAtLogin()
      }
    }
  }

  private func configureLaunchAtLogin() {
    guard #available(macOS 13, *) else { return }

    do {
      let service = SMAppService.mainApp
      if service.status != .enabled {
        try service.register()
        os_log("Launch at login enabled", log: launchLogger, type: .info)
      }
    } catch {
      os_log("Failed to enable launch at login: %{public}@", log: launchLogger, type: .error, String(describing: error))
    }
  }

  private func presentSettingsWindow() {
    if settingsCoordinator == nil {
      settingsCoordinator = SettingsCoordinator(
        configurationStore: configurationStore,
        logMonitor: logMonitor
      )
    }
    settingsCoordinator?.show()
  }
}

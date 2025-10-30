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
  private let launchAtLoginController: LaunchAtLoginControlling

  private var menuBarController: MenuBarController?
  private var logMonitor: LogMonitor?
  private let launchLogger = OSLog(subsystem: "io.utensils.Simmer", category: "LaunchAtLogin")

  override init() {
    configurationStore = ConfigurationStore()
    patternMatcher = RegexPatternMatcher()
    matchEventHandler = MatchEventHandler()
    iconAnimator = IconAnimator()
    let environment = ProcessInfo.processInfo.environment
    if environment["SIMMER_USE_STUB_LAUNCH_AT_LOGIN"] == "1" {
      launchAtLoginController = UITestLaunchAtLoginController(environment: environment)
    } else {
      launchAtLoginController = LaunchAtLoginController()
    }
    super.init()
  }

  // swiftlint:disable function_body_length
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
      quitHandler: { [weak self] in
        self?.handleQuitRequest()
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

    logMonitor.onWarningsUpdate = { [weak menuBarController] _ in
      menuBarController?.handleWarningsUpdate()
    }

    schedulePostLaunchTasks(isRunningUITests: isRunningUITests)

    if shouldShowSettings {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        self?.presentSettingsWindow()
      }
    }
  }
  // swiftlint:enable function_body_length

  func applicationWillTerminate(_ notification: Notification) {
    logMonitor?.stopAll()
  }

  private func schedulePostLaunchTasks(isRunningUITests: Bool) {
    guard let logMonitor else { return }

    DispatchQueue.main.async { [weak self, weak logMonitor] in
      logMonitor?.start()
      guard !isRunningUITests else { return }
      self?.applyLaunchAtLoginPreference()
    }
  }

  private func applyLaunchAtLoginPreference() {
    guard launchAtLoginController.isAvailable else { return }

    do {
      let desired = launchAtLoginController.resolvedPreference()
      try launchAtLoginController.setEnabled(desired)
    } catch {
      os_log(
        "Failed to apply stored Launch at Login preference: %{public}@",
        log: launchLogger,
        type: .error,
        String(describing: error)
      )
    }
  }

  private func presentSettingsWindow() {
    if settingsCoordinator == nil {
      settingsCoordinator = SettingsCoordinator(
        configurationStore: configurationStore,
        logMonitor: logMonitor,
        launchAtLoginController: launchAtLoginController
      )
    }
    settingsCoordinator?.show()
  }

  private func handleQuitRequest() {
    settingsCoordinator?.forceCloseWindow()
    logMonitor?.stopAll()

    for window in NSApp.windows {
      for sheet in window.sheets {
        window.endSheet(sheet, returnCode: .cancel)
        sheet.close()
      }
      window.close()
    }

    NSApp.terminate(nil)
  }
}

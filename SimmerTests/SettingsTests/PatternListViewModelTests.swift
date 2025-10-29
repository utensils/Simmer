//
//  PatternListViewModelTests.swift
//  SimmerTests
//

import XCTest
@testable import Simmer

@MainActor
final class PatternListViewModelTests: XCTestCase {
  func test_toggleEnabled_updatesStoreAndMonitor() {
    let pattern = LogPattern(
      name: "Toggleable",
      regex: "error",
      logPath: "/tmp/log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: true,
      bookmark: nil
    )
    let store = InMemoryStore(initialPatterns: [pattern])
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy()
    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    viewModel.loadPatterns()
    viewModel.toggleEnabled(id: pattern.id)

    XCTAssertEqual(store.loadPatterns().first?.enabled, false)
    XCTAssertEqual(monitor.calls, [.set(pattern.id, false)])
  }

  func test_deletePattern_removesPatternAndStopsMonitoring() {
    let pattern = LogPattern(
      name: "Disposable",
      regex: "warn",
      logPath: "/tmp/log",
      color: CodableColor(red: 0, green: 1, blue: 0),
      animationStyle: .pulse,
      enabled: true,
      bookmark: nil
    )
    let store = InMemoryStore(initialPatterns: [pattern])
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy()
    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    viewModel.loadPatterns()
    viewModel.deletePattern(id: pattern.id)

    XCTAssertTrue(store.loadPatterns().isEmpty)
    XCTAssertEqual(monitor.calls, [.set(pattern.id, false)])
  }

  func test_setLaunchAtLoginEnabled_updatesController() {
    let store = InMemoryStore()
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy(isAvailable: true, storedPreference: false)
    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertTrue(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(launchController.setEnabledCalls, [true])
    XCTAssertNil(viewModel.errorMessage)
  }

  func test_setLaunchAtLoginEnabled_whenControllerThrows_setsErrorAndReverts() {
    let store = InMemoryStore()
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy(isAvailable: true, storedPreference: false)
    launchController.errorToThrow = LaunchAtLoginError.operationFailed(message: "System denied")

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertFalse(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(launchController.setEnabledCalls, [true])
    XCTAssertEqual(viewModel.errorMessage, LaunchAtLoginError.operationFailed(message: "System denied").errorDescription)
  }

  func test_setLaunchAtLoginEnabled_whenNotSupported_setsError() {
    let store = InMemoryStore()
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy(isAvailable: false, storedPreference: false)

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertFalse(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(
      viewModel.errorMessage,
      LaunchAtLoginError.notSupported.errorDescription
    )
  }
}

private final class LogMonitorSpy: LogMonitoring {
  enum Call: Equatable {
    case reload
    case set(UUID, Bool)
  }

  private(set) var calls: [Call] = []

  func reloadPatterns() {
    calls.append(.reload)
  }

  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool) {
    calls.append(.set(patternID, isEnabled))
  }
}

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

    let initialResolvedCalls = launchController.resolvedPreferenceCalls

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertTrue(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(launchController.setEnabledCalls, [true])
    XCTAssertEqual(launchController.resolvedPreferenceCalls, initialResolvedCalls + 1)
    XCTAssertTrue(viewModel.isLaunchAtLoginAvailable)
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

    let initialResolvedCalls = launchController.resolvedPreferenceCalls

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertFalse(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(launchController.setEnabledCalls, [true])
    XCTAssertEqual(launchController.resolvedPreferenceCalls, initialResolvedCalls)
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
    XCTAssertFalse(viewModel.isLaunchAtLoginAvailable)
  }

  func test_setLaunchAtLoginEnabled_updatesWithResolvedPreferenceOverride() {
    let store = InMemoryStore()
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy(isAvailable: true, storedPreference: false)
    launchController.resolvedPreferenceOverride = false

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    let initialResolvedCalls = launchController.resolvedPreferenceCalls

    viewModel.setLaunchAtLoginEnabled(true)

    XCTAssertFalse(viewModel.launchAtLoginEnabled, "View model should reflect resolved preference override")
    XCTAssertEqual(launchController.setEnabledCalls, [true])
    XCTAssertEqual(launchController.resolvedPreferenceCalls, initialResolvedCalls + 1)
  }

  func test_setLaunchAtLoginEnabled_falseDisablesLaunchAtLogin() {
    let store = InMemoryStore()
    let monitor = LogMonitorSpy()
    let launchController = LaunchAtLoginControllerSpy(isAvailable: true, storedPreference: true)
    launchController.resolvedPreferenceOverride = false

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: launchController
    )

    let initialResolvedCalls = launchController.resolvedPreferenceCalls

    viewModel.setLaunchAtLoginEnabled(false)

    XCTAssertFalse(viewModel.launchAtLoginEnabled)
    XCTAssertEqual(launchController.setEnabledCalls, [false])
    XCTAssertEqual(launchController.resolvedPreferenceCalls, initialResolvedCalls + 1)
  }

  func test_exportPatterns_invokesExporterWithCurrentPatterns() {
    let pattern = LogPattern(
      name: "Exportable",
      regex: "ERR",
      logPath: "/tmp/err.log",
      color: CodableColor(red: 0.5, green: 0.2, blue: 0.7),
      animationStyle: .blink,
      enabled: true,
    )
    let store = InMemoryStore(initialPatterns: [pattern])
    let exporter = ConfigurationExporterSpy()
    let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: nil,
      launchAtLoginController: LaunchAtLoginControllerSpy(),
      exporter: exporter,
      exportURLProvider: { exportURL },
      importURLProvider: { nil }
    )

    viewModel.loadPatterns()
    viewModel.exportPatterns()

    XCTAssertEqual(exporter.capturedPatterns, [pattern])
    XCTAssertEqual(exporter.capturedURL, exportURL)
  }

  func test_importPatterns_mergesAndReloadsMonitor() {
    let existing = LogPattern(
      name: "Existing",
      regex: "ERROR",
      logPath: "/tmp/existing.log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: true,
    )
    let incoming = LogPattern(
      id: existing.id,
      name: "Existing",
      regex: "ERROR",
      logPath: "/tmp/new.log",
      color: CodableColor(red: 0, green: 1, blue: 0),
      animationStyle: .pulse,
      enabled: false,
    )
    let additional = LogPattern(
      name: "New",
      regex: "WARN",
      logPath: "/tmp/new.log",
      color: CodableColor(red: 0, green: 0, blue: 1),
      animationStyle: .pulse,
      enabled: true,
    )

    let store = InMemoryStore(initialPatterns: [existing])
    let monitor = LogMonitorSpy()
    let importer = ConfigurationImporterStub(result: [incoming, additional])
    let importURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: LaunchAtLoginControllerSpy(),
      exporter: ConfigurationExporterSpy(),
      importer: importer,
      exportURLProvider: { nil },
      importURLProvider: { importURL }
    )

    viewModel.loadPatterns()
    viewModel.importPatterns()

    let persisted = store.loadPatterns()
    XCTAssertEqual(persisted.count, 2)
    XCTAssertEqual(persisted.first?.logPath, incoming.logPath)
    XCTAssertEqual(persisted.last?.name, additional.name)
    XCTAssertTrue(monitor.calls.contains(.reload))
  }

  func test_importPatterns_whenImporterThrows_setsErrorMessage() {
    let store = InMemoryStore()
    let importer = ConfigurationImporterStub(error: ConfigurationImportError.validationFailed(messages: ["Boom"]))
    let importURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: nil,
      launchAtLoginController: LaunchAtLoginControllerSpy(),
      exporter: ConfigurationExporterSpy(),
      importer: importer,
      exportURLProvider: { nil },
      importURLProvider: { importURL }
    )

    viewModel.importPatterns()

    XCTAssertEqual(
      viewModel.errorMessage,
      ConfigurationImportError.validationFailed(messages: ["Boom"]).errorDescription
    )
  }

  func test_addPattern_whenLimitReached_setsErrorAndDoesNotPersist() {
    let existingPatterns = (0..<20).map { index in
      LogPattern(
        name: "Pattern \(index)",
        regex: "ERROR",
        logPath: "/tmp/pattern\(index).log",
        color: CodableColor(red: 1, green: 0, blue: 0),
        animationStyle: .glow,
        enabled: true,
      )
    }
    let store = InMemoryStore(initialPatterns: existingPatterns)
    let monitor = LogMonitorSpy()
    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: LaunchAtLoginControllerSpy()
    )

    viewModel.loadPatterns()
    let newPattern = LogPattern(
      name: "Overflow",
      regex: "OVERFLOW",
      logPath: "/tmp/overflow.log",
      color: CodableColor(red: 0, green: 0, blue: 1),
      animationStyle: .pulse,
      enabled: true,
    )

    viewModel.addPattern(newPattern)

    XCTAssertEqual(store.loadPatterns().count, 20)
    XCTAssertEqual(viewModel.patterns.count, 20)
    XCTAssertEqual(viewModel.errorMessage, "Maximum 20 patterns supported")
    XCTAssertTrue(monitor.calls.isEmpty)
  }

  func test_importPatterns_whenResultExceedsLimit_setsErrorAndDoesNotSave() {
    let existingPatterns = (0..<19).map { index in
      LogPattern(
        name: "Pattern \(index)",
        regex: "ERROR",
        logPath: "/tmp/pattern\(index).log",
        color: CodableColor(red: 1, green: 0, blue: 0),
        animationStyle: .glow,
        enabled: true,
      )
    }
    let additionalPatterns = (0..<3).map { index in
      LogPattern(
        name: "Imported \(index)",
        regex: "WARN",
        logPath: "/tmp/imported\(index).log",
        color: CodableColor(red: 0, green: 1, blue: 0),
        animationStyle: .pulse,
        enabled: true,
      )
    }

    let store = InMemoryStore(initialPatterns: existingPatterns)
    let importer = ConfigurationImporterStub(result: additionalPatterns)
    let monitor = LogMonitorSpy()
    let importURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let viewModel = PatternListViewModel(
      store: store,
      logMonitor: monitor,
      launchAtLoginController: LaunchAtLoginControllerSpy(),
      exporter: ConfigurationExporterSpy(),
      importer: importer,
      exportURLProvider: { nil },
      importURLProvider: { importURL }
    )

    viewModel.loadPatterns()
    viewModel.importPatterns()

    XCTAssertEqual(store.loadPatterns().count, 19)
    XCTAssertEqual(viewModel.patterns.count, 19)
    XCTAssertEqual(viewModel.errorMessage, "Maximum 20 patterns supported")
    XCTAssertTrue(monitor.calls.isEmpty)
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

private final class ConfigurationExporterSpy: ConfigurationExporting {
  private(set) var capturedPatterns: [LogPattern] = []
  private(set) var capturedURL: URL?

  func export(patterns: [LogPattern], to url: URL) throws {
    capturedPatterns = patterns
    capturedURL = url
  }
}

private final class ConfigurationImporterStub: ConfigurationImporting {
  private let result: [LogPattern]?
  private let error: Error?

  init(result: [LogPattern]) {
    self.result = result
    self.error = nil
  }

  init(error: Error) {
    self.result = nil
    self.error = error
  }

  func importPatterns(from url: URL) throws -> [LogPattern] {
    if let error {
      throw error
    }
    return result ?? []
  }
}

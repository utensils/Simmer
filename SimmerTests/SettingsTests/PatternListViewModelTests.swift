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
    let viewModel = PatternListViewModel(store: store, logMonitor: monitor)

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
    let viewModel = PatternListViewModel(store: store, logMonitor: monitor)

    viewModel.loadPatterns()
    viewModel.deletePattern(id: pattern.id)

    XCTAssertTrue(store.loadPatterns().isEmpty)
    XCTAssertEqual(monitor.calls, [.set(pattern.id, false)])
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

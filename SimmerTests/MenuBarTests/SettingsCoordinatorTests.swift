//
//  SettingsCoordinatorTests.swift
//  SimmerTests
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
final class SettingsCoordinatorTests: XCTestCase {
  override func tearDown() async throws {
    // Close any leftover settings windows to avoid bleeding into other tests.
    NSApp.windows
      .filter { $0.title == "Simmer Settings" }
      .forEach { $0.close() }
  }

  func test_show_createsVisibleWindow() {
    let coordinator = makeCoordinator()

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    let window = coordinator.windowController?.window
    XCTAssertNotNil(window)
    XCTAssertTrue(window?.isVisible ?? false)
  }

  func test_show_reusesExistingWindow() {
    let coordinator = makeCoordinator()

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let firstController = coordinator.windowController

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    XCTAssert(firstController === coordinator.windowController)
  }

  // MARK: - Helpers

  private func makeCoordinator() -> SettingsCoordinator {
    let store = InMemoryStore(initialPatterns: [])
    return SettingsCoordinator(configurationStore: store, logMonitor: nil)
  }
}

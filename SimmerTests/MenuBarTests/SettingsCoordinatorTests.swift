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

  func test_show_createsVisibleWindow() throws {
    // TODO: Move to SimmerUITests - requires full UI context with activated app
    try XCTSkipIf(true, "Test requires UI context - move to SimmerUITests")

    let coordinator = makeCoordinator()

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    let window = coordinator.windowController?.window
    XCTAssertNotNil(window)
    XCTAssertTrue(window?.isVisible ?? false)
  }

  func test_show_reusesExistingWindow() throws {
    // TODO: Move to SimmerUITests - requires full UI context with activated app
    try XCTSkipIf(true, "Test requires UI context - move to SimmerUITests")

    let coordinator = makeCoordinator()

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let firstController = coordinator.windowController

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    XCTAssert(firstController === coordinator.windowController)
  }

  func test_defaultWindowSizing() throws {
    // TODO: Move to SimmerUITests - requires full UI context with activated app
    try XCTSkipIf(true, "Test requires UI context - move to SimmerUITests")

    let coordinator = makeCoordinator()

    coordinator.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    guard let window = coordinator.windowController?.window else {
      XCTFail("Expected window to exist after show()")
      return
    }

    let contentSize = window.contentView?.frame.size ?? .zero
    XCTAssertGreaterThanOrEqual(contentSize.width, 800 - 0.5, "content width \(contentSize.width)")
    XCTAssertGreaterThanOrEqual(contentSize.height, 700 - 0.5, "content height \(contentSize.height)")
    XCTAssertEqual(window.contentMinSize.width, 720, accuracy: 0.5, "min width \(window.contentMinSize.width)")
    XCTAssertEqual(window.contentMinSize.height, 600, accuracy: 0.5, "min height \(window.contentMinSize.height)")
  }

  // MARK: - Helpers

  private func makeCoordinator() -> SettingsCoordinator {
    let store = InMemoryStore(initialPatterns: [])
    return SettingsCoordinator(configurationStore: store, logMonitor: nil)
  }
}

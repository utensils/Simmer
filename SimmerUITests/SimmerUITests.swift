//
//  SimmerUITests.swift
//  SimmerUITests
//
//  Created by James Brink on 10/28/25.
//

import XCTest

internal final class SimmerUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testSettingsWindowOpens() throws {
    let app = XCUIApplication()
    app.launchEnvironment["SIMMER_UI_TEST_SHOW_SETTINGS"] = "1"
    app.launch()

    var window = app.windows["Simmer Settings"]
    var exists = window.waitForExistence(timeout: 8)
    if !exists {
      let fallback = app.windows["Log Patterns"]
      exists = fallback.waitForExistence(timeout: 4)
      if exists {
        window = fallback
      }
    }

    XCTAssertTrue(exists, "Settings window should appear automatically")

    let frame = window.frame
    XCTAssertGreaterThan(frame.width, 500, "Settings window width unexpectedly small")
    XCTAssertGreaterThan(frame.height, 350, "Settings window height unexpectedly small")

    let screenshot = window.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "Settings Window Visible"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

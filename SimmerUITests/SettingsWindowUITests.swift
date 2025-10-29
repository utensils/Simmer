import XCTest

final class SettingsWindowUITests: XCTestCase {
  func testSettingsWindowAppears() {
    let app = XCUIApplication()
    app.launchEnvironment["SIMMER_UI_TEST_SHOW_SETTINGS"] = "1"
    app.launch()
    addTeardownBlock {
      app.terminate()
    }

    var targetWindow = app.windows["Simmer Settings"]
    var exists = targetWindow.waitForExistence(timeout: 8)
    if !exists {
      let fallbackWindow = app.windows["Log Patterns"]
      exists = fallbackWindow.waitForExistence(timeout: 4)
      if exists {
        targetWindow = fallbackWindow
      }
    }

    let debugDescription = app.debugDescription
    let treeAttachment = XCTAttachment(string: debugDescription)
    treeAttachment.name = "Accessibility Tree"
    treeAttachment.lifetime = .keepAlways
    add(treeAttachment)

    XCTAssertTrue(exists, "Settings window did not appear")
    XCTAssertGreaterThan(targetWindow.frame.width, 500, "Settings window width unexpectedly small")
    XCTAssertGreaterThan(targetWindow.frame.height, 350, "Settings window height unexpectedly small")

    if exists {
      let screenshot = targetWindow.screenshot()
      let attachment = XCTAttachment(screenshot: screenshot)
      attachment.name = "Settings Window"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
}

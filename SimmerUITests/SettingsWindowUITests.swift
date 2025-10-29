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

  func testLaunchAtLoginToggleRespondsToInteraction() {
    let app = XCUIApplication()
    app.launchEnvironment["SIMMER_UI_TEST_SHOW_SETTINGS"] = "1"
    app.launchEnvironment["SIMMER_USE_STUB_LAUNCH_AT_LOGIN"] = "1"
    app.launchEnvironment["SIMMER_UI_TEST_LAUNCH_AT_LOGIN_AVAILABLE"] = "1"
    app.launchEnvironment["SIMMER_UI_TEST_LAUNCH_AT_LOGIN_INITIAL"] = "1"
    app.launch()
    addTeardownBlock {
      app.terminate()
    }

    let toggle = app.switches["launchAtLoginToggle"].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: 8), "Launch at Login toggle not found")

    XCTAssertEqual(Self.switchValue(toggle), "1", "Expected toggle to start enabled")

    toggle.tap()
    XCTAssertEqual(Self.switchValue(toggle), "0", "Expected toggle to disable after tap")

    toggle.tap()
    XCTAssertEqual(Self.switchValue(toggle), "1", "Expected toggle to re-enable after second tap")
  }

  private static func switchValue(_ element: XCUIElement) -> String? {
    if let string = element.value as? String {
      return string
    }
    if let number = element.value as? NSNumber {
      return number.stringValue
    }
    return nil
  }
}

//
//  SimmerUITests.swift
//  SimmerUITests
//
//  Created by James Brink on 10/28/25.
//

import XCTest

final class SimmerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        // Terminate app after each test
        XCUIApplication().terminate()
    }

    @MainActor
    func testSettingsWindowOpens() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for app to launch
        sleep(2)

        print("📱 Taking screenshot 1: App launched")
        let screenshot1 = XCUIScreen.main.screenshot()
        let attachment1 = XCTAttachment(screenshot: screenshot1)
        attachment1.name = "01_app_launched"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Find and click the menu bar item
        // For menu bar apps, we need to use menu bar extras
        let menuBarsQuery = app.menuBars
        print("📱 Menu bars count: \(menuBarsQuery.count)")

        // Try to find Simmer menu bar item
        let menuBarItem = app.menuBarItems["Simmer"]
        if menuBarItem.exists {
            print("📱 Found Simmer menu bar item")
            menuBarItem.click()
        } else {
            // Try status items
            print("📱 Looking for status items...")
            let statusItem = app.statusItems.firstMatch
            if statusItem.exists {
                print("📱 Found status item")
                statusItem.click()
            } else {
                print("📱 No status items found, trying menu extras")
                // For LSUIElement apps, check menu extras
                let menuExtra = app.menuBarItems.firstMatch
                if menuExtra.exists {
                    print("📱 Found menu extra")
                    menuExtra.click()
                }
            }
        }

        sleep(1)

        print("📱 Taking screenshot 2: After clicking menu bar")
        let screenshot2 = XCUIScreen.main.screenshot()
        let attachment2 = XCTAttachment(screenshot: screenshot2)
        attachment2.name = "02_menu_opened"
        attachment2.lifetime = .keepAlways
        add(attachment2)

        // Click Settings menu item
        let settingsMenuItem = app.menuItems["Settings"]
        print("📱 Settings menu item exists: \(settingsMenuItem.exists)")

        if settingsMenuItem.exists {
            print("📱 Clicking Settings menu item")
            settingsMenuItem.click()
        }

        sleep(1)

        print("📱 Taking screenshot 3: After clicking Settings")
        let screenshot3 = XCUIScreen.main.screenshot()
        let attachment3 = XCTAttachment(screenshot: screenshot3)
        attachment3.name = "03_after_settings_click"
        attachment3.lifetime = .keepAlways
        add(attachment3)

        // Check if settings window appeared
        let settingsWindow = app.windows["Simmer Settings"]
        print("📱 Settings window exists: \(settingsWindow.exists)")

        if !settingsWindow.exists {
            // Check all windows
            print("📱 All windows:")
            for window in app.windows.allElementsBoundByIndex {
                print("  - \(window.title)")
            }
        }

        sleep(1)

        print("📱 Taking screenshot 4: Final state")
        let screenshot4 = XCUIScreen.main.screenshot()
        let attachment4 = XCTAttachment(screenshot: screenshot4)
        attachment4.name = "04_final_state"
        attachment4.lifetime = .keepAlways
        add(attachment4)

        // Dump element hierarchy
        print("📱 Full element hierarchy:")
        print(app.debugDescription)

        XCTAssertTrue(settingsWindow.exists, "Settings window should be visible")
    }
}

//
//  MenuBuilderTests.swift
//  SimmerTests
//
//  Exercises the status-item menu construction logic.
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
final class MenuBuilderTests: XCTestCase {
  func test_buildMatchHistoryMenu_whenNoMatches_showsEmptyStateAndDisabledClear() {
    let handler = MatchEventHandler()
    let builder = MenuBuilder(matchEventHandler: handler, dateProvider: { Date(timeIntervalSince1970: 0) })

    let menu = builder.buildMatchHistoryMenu()

    XCTAssertEqual(menu.items.count, 5)
    XCTAssertEqual(menu.items.first?.title, "No recent matches")
    XCTAssertEqual(menu.items.first?.isEnabled, false)
    XCTAssertTrue(menu.items[1].isSeparatorItem)
    XCTAssertEqual(menu.items[2].title, "Clear All")
    XCTAssertEqual(menu.items[2].isEnabled, false)
    XCTAssertEqual(menu.items[3].title, "Settings")
    XCTAssertEqual(menu.items[4].title, "Quit Simmer")
  }

  func test_buildMatchHistoryMenu_limitsToTenRecentMatchesAndShowsLatestFirst() {
    let handler = MatchEventHandler()
    let builder = MenuBuilder(matchEventHandler: handler, dateProvider: { Date() })

    for index in 1...12 {
      handler.handleMatch(
        pattern: makePattern(name: "Pattern \(index)"),
        line: String(repeating: "match \(index) ", count: 10),
        lineNumber: index,
        filePath: "/tmp/test.log"
      )
    }

    let menu = builder.buildMatchHistoryMenu()

    XCTAssertEqual(menu.items.count, 14)
    let historyItems = menu.items.prefix(10)
    XCTAssertTrue(historyItems.allSatisfy { !$0.isSeparatorItem })
    XCTAssertEqual(historyItems.first?.representedObject as? MatchEvent, handler.recentMatches(limit: 1).first)
    XCTAssertTrue(historyItems.first?.title.contains("Pattern 12") ?? false)
    XCTAssertTrue(historyItems.last?.title.contains("Pattern 3") ?? false)
    XCTAssertTrue(menu.items[10].isSeparatorItem)
    XCTAssertEqual(menu.items[11].title, "Clear All")
    XCTAssertEqual(menu.items[11].isEnabled, true)
  }

  func test_clearAllMenuItem_invokesHandlerClearHistory() {
    let handler = MatchEventHandler()
    handler.handleMatch(
      pattern: makePattern(name: "Pattern"),
      line: "A match occurred",
      lineNumber: 1,
      filePath: "/tmp/test.log"
    )

    let builder = MenuBuilder(
      matchEventHandler: handler,
      dateProvider: { Date() },
      settingsHandler: {},
      quitHandler: {}
    )
    let menu = builder.buildMatchHistoryMenu()

    guard let clearItem = menu.item(withTitle: "Clear All") else {
      XCTFail("Expected Clear All item")
      return
    }

    XCTAssertEqual(handler.history.isEmpty, false)
    _ = clearItem.target?.perform(clearItem.action, with: clearItem)
    XCTAssertTrue(handler.history.isEmpty)
  }

  func test_settingsMenuItem_invokesProvidedHandler() {
    let handler = MatchEventHandler()
    var settingsInvoked = false
    let builder = MenuBuilder(
      matchEventHandler: handler,
      dateProvider: { Date() },
      settingsHandler: { settingsInvoked = true },
      quitHandler: {}
    )

    let menu = builder.buildMatchHistoryMenu()
    guard let settingsItem = menu.item(withTitle: "Settings") else {
      XCTFail("Expected Settings item")
      return
    }

    _ = settingsItem.target?.perform(settingsItem.action, with: settingsItem)
    XCTAssertTrue(settingsInvoked)
  }

  func test_quitMenuItem_invokesProvidedHandler() {
    let handler = MatchEventHandler()
    var quitInvoked = false
    let builder = MenuBuilder(
      matchEventHandler: handler,
      dateProvider: { Date() },
      settingsHandler: {},
      quitHandler: { quitInvoked = true }
    )

    let menu = builder.buildMatchHistoryMenu()
    guard let quitItem = menu.item(withTitle: "Quit Simmer") else {
      XCTFail("Expected Quit item")
      return
    }

    _ = quitItem.target?.perform(quitItem.action, with: quitItem)
    XCTAssertTrue(quitInvoked)
  }

  func test_warningItemAppearsAfterThreshold_andDismissClearsWarning() {
    let handler = MatchEventHandler()
    let builder = MenuBuilder(matchEventHandler: handler, dateProvider: { Date(timeIntervalSince1970: 0) })
    let pattern = makePattern(name: "Verbose")

    (0..<50).forEach { index in
      handler.handleMatch(
        pattern: pattern,
        line: "line \(index)",
        lineNumber: index,
        filePath: "/tmp/test.log"
      )
    }

    let menu = builder.buildMatchHistoryMenu()
    guard let warningItem = menu.items.first else {
      XCTFail("Expected warning item")
      return
    }

    XCTAssertTrue(warningItem.title.contains("⚠️"))
    XCTAssertFalse(handler.activeWarnings.isEmpty)

    _ = warningItem.target?.perform(warningItem.action, with: warningItem)

    XCTAssertTrue(handler.activeWarnings.isEmpty)
  }

  // MARK: - Helpers

  private func makePattern(name: String) -> LogPattern {
    LogPattern(
      name: name,
      regex: ".*",
      logPath: "/tmp/test.log",
      color: CodableColor(red: 1, green: 0, blue: 0)
    )
  }
}

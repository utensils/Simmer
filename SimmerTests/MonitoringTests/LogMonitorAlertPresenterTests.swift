//
//  LogMonitorAlertPresenterTests.swift
//  SimmerTests
//
//  Exercises missing-file prompt behaviours in ``NSAlertPresenter``.
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
final class LogMonitorAlertPresenterTests: XCTestCase {
  func test_presentMissingFilePrompt_returnsLocateResponse() {
    let alert = StubAlertPrompt(response: .alertFirstButtonReturn)
    let activator = StubApplication()

    let action = MissingFilePromptRunner.present(
      application: activator,
      prompt: alert,
      patternName: "API Errors",
      missingPath: "/Users/alice/logs/api.log"
    )

    XCTAssertEqual(action, .locate)
    XCTAssertEqual(alert.messageText, "Locate Missing Log File")
    XCTAssertTrue(alert.informativeText.contains("API Errors"))
    XCTAssertEqual(alert.buttonTitles, ["Locate…", "Keep Disabled"])
    XCTAssertTrue(activator.didActivate)
  }

  func test_presentMissingFilePrompt_returnsDisableResponse() {
    let alert = StubAlertPrompt(response: .alertSecondButtonReturn)

    let action = MissingFilePromptRunner.present(
      application: nil,
      prompt: alert,
      patternName: "Queue",
      missingPath: "/tmp/queue.log"
    )

    XCTAssertEqual(action, .disable)
    XCTAssertEqual(alert.buttonTitles.last, "Keep Disabled")
  }

  func test_presentMissingFilePrompt_returnsCancelForOtherResponses() {
    let alert = StubAlertPrompt(response: .abort)

    let action = MissingFilePromptRunner.present(
      application: nil,
      prompt: alert,
      patternName: "Workers",
      missingPath: "/var/log/workers.log"
    )

    XCTAssertEqual(action, .cancel)
  }
}

// MARK: - Test Doubles

private final class StubAlertPrompt: AlertPrompting {
  fileprivate var buttonTitles: [String] = []
  fileprivate private(set) var recordedKeyEquivalents: [String] = []
  var alertStyle: NSAlert.Style = .warning
  var messageText: String = ""
  var informativeText: String = ""
  var icon: NSImage?

  private let modalResponse: NSApplication.ModalResponse
  private var buttons: [StubAlertButton] = []

  init(response: NSApplication.ModalResponse) {
    self.modalResponse = response
  }

  @discardableResult
  func addButton(withTitle title: String) -> AlertButtonHandling {
    buttonTitles.append(title)
    let button = StubAlertButton(onKeyEquivalentChange: { [weak self] key in
      self?.recordedKeyEquivalents.append(key)
    })
    buttons.append(button)
    return button
  }

  func runModal() -> NSApplication.ModalResponse {
    modalResponse
  }
}

private final class StubAlertButton: AlertButtonHandling {
  private let onChange: (String) -> Void
  var keyEquivalent: String = "" {
    didSet { onChange(keyEquivalent) }
  }

  init(onKeyEquivalentChange: @escaping (String) -> Void) {
    onChange = onKeyEquivalentChange
  }
}

private final class StubApplication: NSApplicationActivating {
  private(set) var didActivate = false

  func activate(ignoringOtherApps flag: Bool) {
    didActivate = flag
  }
}

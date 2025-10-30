//
//  LogMonitorPatternAccessValidatorTests.swift
//  SimmerTests
//
//  Covers missing file recovery flows for LogMonitorPatternAccessValidator.
//

import Foundation
import os.log
import XCTest
@testable import Simmer

final class LogMonitorPatternAccessValidatorTests: XCTestCase {
  func test_validateAccess_returnsUpdatedPattern_whenUserLocatesReplacementFile() async throws {
    let missingPath = makeUniqueMissingPath()
    let replacementURL = try makeTemporaryLogFile()

    let pattern = LogPattern(
      name: "API Errors",
      regex: ".*",
      logPath: missingPath,
      color: CodableColor(red: 1, green: 0, blue: 0)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.locate],
      accessResults: [.success(replacementURL)]
    )

    XCTAssertEqual(result.returnedPatternPath, replacementURL.path)
    XCTAssertTrue(result.didChangeConfiguration)
    XCTAssertEqual(result.persistedPatterns.first?.logPath, replacementURL.path)
    XCTAssertTrue(result.didNotify)
    let prompts = result.prompts
    let alerts = result.alerts
    XCTAssertEqual(prompts.count, 1)
    XCTAssertTrue(alerts.isEmpty)
  }

  func test_validateAccess_disablesPattern_whenUserCancelsPrompt() async {
    let missingPath = makeUniqueMissingPath()
    let pattern = LogPattern(
      name: "Ops Alerts",
      regex: ".*",
      logPath: missingPath,
      color: CodableColor(red: 0, green: 0, blue: 1)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.cancel],
      accessResults: []
    )

    XCTAssertNil(result.returnedPatternPath)
    XCTAssertTrue(result.didChangeConfiguration)
    XCTAssertEqual(result.persistedPatterns.first?.enabled, false)
    let prompts = result.prompts
    let alerts = result.alerts
    XCTAssertEqual(prompts.count, 1)
    XCTAssertTrue(alerts.isEmpty)
  }

  func test_validateAccess_reprompts_whenFileSelectionCancelled() async {
    let missingPath = makeUniqueMissingPath()
    let pattern = LogPattern(
      name: "Queue",
      regex: ".*",
      logPath: missingPath,
      color: CodableColor(red: 0, green: 1, blue: 0)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.locate, .cancel],
      accessResults: [.failure(FileAccessError.userCancelled)]
    )

    XCTAssertNil(result.returnedPatternPath)
    XCTAssertTrue(result.didChangeConfiguration)
    XCTAssertEqual(result.persistedPatterns.first?.enabled, false)
    let prompts = result.prompts
    let alerts = result.alerts
    XCTAssertEqual(prompts.count, 2)
    XCTAssertTrue(alerts.isEmpty)
  }

  func test_validateAccess_showsAlert_whenSelectedFileUnreadable() async {
    let missingPath = makeUniqueMissingPath()
    let unreadablePath = NSTemporaryDirectory() + "unreadable-\(UUID().uuidString).log"
    let pattern = LogPattern(
      name: "Services",
      regex: ".*",
      logPath: missingPath,
      color: CodableColor(red: 0.3, green: 0.3, blue: 0.3)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.locate, .cancel],
      accessResults: [.failure(FileAccessError.fileNotAccessible(path: unreadablePath))]
    )

    XCTAssertNil(result.returnedPatternPath)
    XCTAssertTrue(result.didChangeConfiguration)
    let prompts = result.prompts
    let alerts = result.alerts
    XCTAssertEqual(prompts.count, 2)
    XCTAssertEqual(alerts.count, 1)
    XCTAssertEqual(alerts.first?.title, "Unable to read file")
    XCTAssertTrue(alerts.first?.message.contains(unreadablePath) ?? false)
  }

  func test_validateAccess_doesNotPersist_whenLocatedPathMatchesExisting() async {
    let existingPath = makeUniqueMissingPath()
    let pattern = LogPattern(
      name: "Same Path",
      regex: ".*",
      logPath: existingPath,
      color: CodableColor(red: 0.1, green: 0.2, blue: 0.3)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.locate],
      accessResults: [.success(URL(fileURLWithPath: existingPath))]
    )

    XCTAssertEqual(result.returnedPatternPath, existingPath)
    XCTAssertFalse(result.didChangeConfiguration)
    XCTAssertEqual(result.persistedPatterns.first?.logPath, existingPath)
    XCTAssertFalse(result.didNotify)
  }

  func test_validateAccess_showsGenericError_whenLocateThrowsUnknownError() async {
    let missingPath = makeUniqueMissingPath()
    let pattern = LogPattern(
      name: "Generic Error",
      regex: ".*",
      logPath: missingPath,
      color: CodableColor(red: 0.6, green: 0.4, blue: 0.2)
    )
    let result = await runValidation(
      for: pattern,
      alertActions: [.locate, .disable],
      accessResults: [.failure(GenericError())]
    )

    XCTAssertNil(result.returnedPatternPath)
    XCTAssertTrue(result.didChangeConfiguration)
    XCTAssertEqual(result.alerts.count, 1)
    XCTAssertEqual(result.alerts.first?.title, "Unable to read file")
    XCTAssertEqual(result.prompts.count, 2)
  }

  // MARK: - Helpers

  private func makeUniqueMissingPath() -> String {
    let path = NSTemporaryDirectory() + "missing-\(UUID().uuidString).log"
    FileManager.default.createFile(atPath: path, contents: nil)
    try? FileManager.default.removeItem(atPath: path)
    return path
  }

  private func makeTemporaryLogFile() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      "log-\(UUID().uuidString).log"
    )
    let contents = Data("hello\n".utf8)
    try contents.write(to: url)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }
}

private struct GenericError: Error {}

// MARK: - Test Doubles

private struct ValidationRunResult {
  let returnedPatternPath: String?
  let didChangeConfiguration: Bool
  let persistedPatterns: [LogPattern]
  let prompts: [(pattern: String, path: String)]
  let alerts: [(title: String, message: String)]
  let didNotify: Bool
}

private func runValidation(
  for pattern: LogPattern,
  alertActions: [MissingFileAlertAction],
  accessResults: [Result<URL, Error>]
) async -> ValidationRunResult {
  await MainActor.run {
    let store = InMemoryStore(initialPatterns: [pattern])
    let presenter = StubAlertPresenter(actions: alertActions)
    let fileAccessManager = StubFileAccessManager(results: accessResults)
    var didNotify = false
    let validator = LogMonitorPatternAccessValidator(
      configurationStore: store,
      alertPresenter: presenter,
      logger: OSLog(subsystem: "io.utensils.SimmerTests", category: "Validator"),
      notifyPatternsDidChange: { didNotify = true },
      fileAccessManager: fileAccessManager
    )
    let outcome = validator.validateAccess(for: pattern)
    return ValidationRunResult(
      returnedPatternPath: outcome.pattern?.logPath,
      didChangeConfiguration: outcome.didChangeConfiguration,
      persistedPatterns: store.loadPatterns(),
      prompts: presenter.missingFilePrompts,
      alerts: presenter.alertMessages,
      didNotify: didNotify
    )
  }
}

@MainActor
private final class StubAlertPresenter: LogMonitorAlertPresenting {
  private var queuedActions: [MissingFileAlertAction]
  private(set) var prompts: [(pattern: String, path: String)] = []
  private(set) var alerts: [(title: String, message: String)] = []

  init(actions: [MissingFileAlertAction]) {
    self.queuedActions = actions
  }

  func presentAlert(title: String, message: String) {
    alerts.append((title, message))
  }

  func presentMissingFilePrompt(
    patternName: String,
    missingPath: String
  ) -> MissingFileAlertAction {
    prompts.append((pattern: patternName, path: missingPath))
    if queuedActions.isEmpty {
      return .cancel
    }
    return queuedActions.removeFirst()
  }

  var missingFilePrompts: [(pattern: String, path: String)] { prompts }
  var alertMessages: [(title: String, message: String)] { alerts }
}

@MainActor
private final class StubFileAccessManager: FileAccessManaging {
  private var results: [Result<URL, Error>]

  init(results: [Result<URL, Error>]) {
    self.results = results
  }

  func requestAccess(allowedFileTypes: [String]?) throws -> URL {
    guard !results.isEmpty else {
      throw FileAccessError.userCancelled
    }
    let result = results.removeFirst()
    switch result {
    case .success(let url):
      return url
    case .failure(let error):
      throw error
    }
  }
}

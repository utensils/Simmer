//
//  ConfigurationExportImportTests.swift
//  SimmerTests
//
//  Verifies JSON export/import of pattern configurations.

import XCTest
@testable import Simmer

final class ConfigurationExportImportTests: XCTestCase {
  private var temporaryDirectoryURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    temporaryDirectoryURL = tempDir
  }

  override func tearDownWithError() throws {
    if let url = temporaryDirectoryURL {
      try? FileManager.default.removeItem(at: url)
    }
    temporaryDirectoryURL = nil
    try super.tearDownWithError()
  }

  func test_exportThenImportRoundTrip_preservesPatterns() throws {
    let patterns = [makePattern(name: "Errors"), makePattern(name: "Warnings", regex: "WARN"),]
    let exporter = ConfigurationExporter(dateProvider: { Date(timeIntervalSince1970: 1_000) })
    let importer = ConfigurationImporter()
    let destination = temporaryDirectoryURL.appendingPathComponent("patterns.json")

    try exporter.export(patterns: patterns, to: destination)

    let imported = try importer.importPatterns(from: destination)
    XCTAssertEqual(imported.count, patterns.count)
    XCTAssertEqual(imported.map(\.name), patterns.map(\.name))
  }

  func test_importWithInvalidRegexThrowsValidationError() throws {
    let invalidPattern = makePattern(name: "Broken", regex: "(")
    let snapshot = ConfigurationSnapshot(patterns: [invalidPattern])
    let url = temporaryDirectoryURL.appendingPathComponent("invalid.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    try data.write(to: url)

    let importer = ConfigurationImporter()

    do {
      _ = try importer.importPatterns(from: url)
      XCTFail("Expected import to fail")
    } catch let error as ConfigurationImportError {
      if case .validationFailed(let messages) = error {
        XCTAssertTrue(messages.contains { $0.contains("Broken") })
      } else {
        XCTFail("Expected validationFailed, received \(error)")
      }
    }
  }

  func test_importRejectsUnsupportedVersion() throws {
    let pattern = makePattern(name: "Legacy")
    let snapshot = ConfigurationSnapshot(version: 99, exportedAt: Date(), patterns: [pattern])
    let url = temporaryDirectoryURL.appendingPathComponent("legacy.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    try data.write(to: url)

    let importer = ConfigurationImporter()

    do {
      _ = try importer.importPatterns(from: url)
      XCTFail("Expected unsupported version error")
    } catch let error as ConfigurationImportError {
      if case .unsupportedVersion(let version) = error {
        XCTAssertEqual(version, 99)
      } else {
        XCTFail("Expected unsupportedVersion, received \(error)")
      }
    }
  }

  // MARK: - Helpers

  private func makePattern(name: String, regex: String = "ERROR") -> LogPattern {
    LogPattern(
      name: name,
      regex: regex,
      logPath: "/tmp/\(name.lowercased()).log",
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: true
    )
  }
}

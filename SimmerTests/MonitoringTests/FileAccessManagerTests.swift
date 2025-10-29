//
//  FileAccessManagerTests.swift
//  SimmerTests
//
//  Verifies non-sandboxed file selection flows.
//

import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import Simmer

final class FileAccessManagerTests: XCTestCase {
  func test_requestAccess_returnsSelectedURL() async throws {
    let temporaryURL = makeTemporaryFile()
    let panel = MockOpenPanel()
    panel.modalResponse = .OK
    panel.mockURL = temporaryURL

    let manager = await MainActor.run { FileAccessManager(panelFactory: { panel }) }

    let url = try await MainActor.run { try manager.requestAccess() }

    XCTAssertEqual(url, temporaryURL)
    XCTAssertEqual(panel.runModalCallCount, 1)
  }

  func test_requestAccess_throwsWhenUserCancels() async {
    let panel = MockOpenPanel()
    panel.modalResponse = .cancel

    let manager = await MainActor.run { FileAccessManager(panelFactory: { panel }) }

    do {
      _ = try await MainActor.run { try manager.requestAccess() }
      XCTFail("Expected requestAccess to throw")
    } catch {
      XCTAssertEqual(error as? FileAccessError, .userCancelled)
    }
  }

  func test_requestAccess_throwsWhenFileUnreadable() async {
    let panel = MockOpenPanel()
    panel.modalResponse = .OK
    let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent("missing.log")
    panel.mockURL = missingURL

    let manager = await MainActor.run { FileAccessManager(panelFactory: { panel }) }

    do {
      _ = try await MainActor.run { try manager.requestAccess() }
      XCTFail("Expected requestAccess to throw")
    } catch {
      XCTAssertEqual(
        error as? FileAccessError,
        .fileNotAccessible(path: missingURL.path)
      )
    }
  }

  func test_requestAccess_setsAllowedContentTypes() async {
    let panel = MockOpenPanel()
    panel.modalResponse = .cancel

    let manager = await MainActor.run { FileAccessManager(panelFactory: { panel }) }

    _ = try? await MainActor.run { try manager.requestAccess(allowedFileTypes: ["log", "txt"]) }
    let identifiers = Set(panel.allowedContentTypes.map(\.identifier))
    let expected = Set(["log", "txt"].compactMap { UTType(filenameExtension: $0)?.identifier })
    XCTAssertEqual(identifiers, expected)
  }
}

// MARK: - Test Doubles

private final class MockOpenPanel: NSOpenPanel {
  var modalResponse: NSApplication.ModalResponse = .cancel
  var mockURL: URL?
  private(set) var runModalCallCount = 0

  override func runModal() -> NSApplication.ModalResponse {
    self.runModalCallCount += 1
    return self.modalResponse
  }

  override var url: URL? {
    self.mockURL
  }
}

// MARK: - Helpers

private func makeTemporaryFile() -> URL {
  let directory = FileManager.default.temporaryDirectory
  let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("log")
  FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8), attributes: nil)
  return url
}

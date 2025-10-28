//
//  FileWatcherTests.swift
//  SimmerTests
//

import XCTest
@testable import Simmer

final class FileWatcherTests: XCTestCase {
  private let path = "/tmp/test.log"
  private var fileSystem: MockFileSystem!
  private var eventSource: TestFileSystemEventSource!
  private var delegate: TestFileWatcherDelegate!
  private var watcher: FileWatcher!

  override func setUpWithError() throws {
    try super.setUpWithError()
    fileSystem = MockFileSystem()
    fileSystem.overwriteFile(path, with: "initial\n")
    eventSource = TestFileSystemEventSource()
    delegate = TestFileWatcherDelegate()

    watcher = FileWatcher(
      path: path,
      fileSystem: fileSystem,
      queue: DispatchQueue(label: "com.quantierra.Simmer.FileWatcherTests"),
      sourceFactory: { _, _, _ in
        self.eventSource
      }
    )
    watcher.delegate = delegate
    try watcher.start()
  }

  override func tearDown() {
    watcher.stop()
    watcher = nil
    delegate = nil
    eventSource = nil
    fileSystem = nil
    super.tearDown()
  }

  func test_handleFileEvent_whenLinesAppended_notifiesDelegate() {
    delegate.linesExpectation = expectation(description: "Received appended lines")
    fileSystem.append("ERROR one\n", to: path)
    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedLines.flatMap { $0 }, ["ERROR one"])
  }

  func test_handleFileEvent_whenFileDeleted_reportsError() {
    delegate.errorExpectation = expectation(description: "Reported deleted file")
    let descriptor = fileSystem.descriptor(forPath: path)!
    fileSystem.readFailures[descriptor] = ENOENT

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.first, .fileDeleted(path: path))
  }

  func test_handleFileEvent_whenPermissionDenied_reportsError() {
    delegate.errorExpectation = expectation(description: "Reported permission denied")
    let descriptor = fileSystem.descriptor(forPath: path)!
    fileSystem.readFailures[descriptor] = EACCES

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.first, .permissionDenied(path: path))
  }

  func test_handleFileEvent_whenMultipleRapidEvents_readsAllLinesInOrder() {
    delegate.linesExpectation = expectation(description: "Received multiple batches")
    delegate.linesExpectation?.expectedFulfillmentCount = 2

    fileSystem.append("line one\n", to: path)
    eventSource.trigger()

    fileSystem.append("line two\n", to: path)
    eventSource.trigger()

    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedLines.count, 2)
    XCTAssertEqual(delegate.receivedLines[0], ["line one"])
    XCTAssertEqual(delegate.receivedLines[1], ["line two"])
  }
}

// MARK: - Test Doubles

private final class TestFileSystemEventSource: FileSystemEventSource {
  private var eventHandler: (() -> Void)?
  private var cancelHandler: (() -> Void)?
  private(set) var resumed = false
  private(set) var canceled = false

  func setEventHandler(handler: @escaping () -> Void) {
    eventHandler = handler
  }

  func setCancelHandler(handler: @escaping () -> Void) {
    cancelHandler = handler
  }

  func resume() {
    resumed = true
  }

  func cancel() {
    canceled = true
    cancelHandler?()
  }

  func trigger() {
    eventHandler?()
  }
}

private final class TestFileWatcherDelegate: FileWatcherDelegate {
  var receivedLines: [[String]] = []
  var receivedErrors: [FileWatcherError] = []
  var linesExpectation: XCTestExpectation?
  var errorExpectation: XCTestExpectation?

  func fileWatcher(_ watcher: FileWatcher, didReadLines lines: [String]) {
    receivedLines.append(lines)
    linesExpectation?.fulfill()
  }

  func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcherError) {
    receivedErrors.append(error)
    errorExpectation?.fulfill()
  }
}

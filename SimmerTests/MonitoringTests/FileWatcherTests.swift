//
//  FileWatcherTests.swift
//  SimmerTests
//

import Darwin
import XCTest
@testable import Simmer

internal final class FileWatcherTests: XCTestCase {
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
      queue: DispatchQueue(label: "io.utensils.Simmer.FileWatcherTests"),
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
    guard let descriptor = fileSystem.descriptor(forPath: path) else {
      XCTFail("Failed to get descriptor for path")
      return
    }
    fileSystem.readFailures[descriptor] = ENOENT

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.first, .fileDeleted(path: path))
  }

  func test_handleFileEvent_whenPermissionDenied_reportsError() {
    delegate.errorExpectation = expectation(description: "Reported permission denied")
    guard let descriptor = fileSystem.descriptor(forPath: path) else {
      XCTFail("Failed to get descriptor for path")
      return
    }
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

  func test_stop_preventsErrorWhenEventArrivesAfterCancellation() {
    let noErrorExpectation = expectation(description: "No error reported after stop")
    noErrorExpectation.isInverted = true
    delegate.errorExpectation = noErrorExpectation

    watcher.stop()
    eventSource.trigger()

    wait(for: [noErrorExpectation], timeout: 0.1)
    XCTAssertTrue(delegate.receivedErrors.isEmpty)
  }

  func test_handleFileEvent_whenPartialLineBuffered_emitsAfterCompletion() {
    fileSystem.append("partial", to: path)
    eventSource.trigger()
    XCTAssertTrue(delegate.receivedLines.isEmpty)

    delegate.linesExpectation = expectation(description: "Emits completed line")
    fileSystem.append(" line\n", to: path)
    eventSource.trigger()

    waitForExpectations(timeout: 1)
    XCTAssertEqual(delegate.receivedLines.last, ["partial line"])
  }

  func test_handleFileEvent_whenLseekFails_reportsErrorAndStops() {
    delegate.errorExpectation = expectation(description: "Reported lseek failure")
    guard let descriptor = fileSystem.descriptor(forPath: path) else {
      XCTFail("Failed to get descriptor for path")
      return
    }
    fileSystem.lseekFailures[descriptor] = EBADF

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.last, .fileDescriptorInvalid)
    XCTAssertNil(fileSystem.descriptor(forPath: path))
  }

  func test_handleFileEvent_whenReadReturnsNoData_doesNotEmitLines() {
    eventSource.trigger()
    XCTAssertTrue(delegate.receivedLines.isEmpty)
  }

  func test_handleFileEvent_whenReadFailsWithEPERM_reportsPermissionDenied() {
    delegate.errorExpectation = expectation(description: "Reported EPERM")
    guard let descriptor = fileSystem.descriptor(forPath: path) else {
      XCTFail("Failed to get descriptor for path")
      return
    }
    fileSystem.readFailures[descriptor] = EPERM

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.last, .permissionDenied(path: path))
  }

  func test_handleFileEvent_whenReadFailsWithUnknownError_reportsDescriptorInvalid() {
    delegate.errorExpectation = expectation(description: "Reported default error")
    guard let descriptor = fileSystem.descriptor(forPath: path) else {
      XCTFail("Failed to get descriptor for path")
      return
    }
    fileSystem.readFailures[descriptor] = EIO

    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.last, .fileDescriptorInvalid)
  }

  func test_handleFileEvent_whenDescriptorInvalid_reportsErrorImmediately() {
    delegate.errorExpectation = expectation(description: "Reported invalid descriptor")
    watcher.testingSetFileDescriptor(-1)
    eventSource.trigger()
    waitForExpectations(timeout: 1)

    XCTAssertEqual(delegate.receivedErrors.last, .fileDescriptorInvalid)
  }

  func test_handleFileEvent_respectsMaxBytesPerEventLimit() {
    let limitedPath = "/tmp/limit.log"
    let limitedFileSystem = MockFileSystem()
    limitedFileSystem.overwriteFile(limitedPath, with: "")
    let localDelegate = TestFileWatcherDelegate()
    let limitedWatcher = FileWatcher(
      path: limitedPath,
      fileSystem: limitedFileSystem,
      queue: DispatchQueue(label: "io.utensils.Simmer.FileWatcherTests.limited"),
      bufferSize: 4,
      maxBytesPerEvent: 8,
      sourceFactory: { _, _, _ in TestFileSystemEventSource() }
    )
    localDelegate.linesExpectation = expectation(description: "Read limited chunk")
    limitedWatcher.delegate = localDelegate
    try? limitedWatcher.start()
    defer { limitedWatcher.stop() }

    guard let descriptor = limitedFileSystem.descriptor(forPath: limitedPath) else {
      XCTFail("Descriptor unavailable")
      return
    }

    limitedFileSystem.append("abc\ndef\nXYZ", to: limitedPath)
    limitedWatcher.testingHandleFileEvent()

    waitForExpectations(timeout: 1)

    XCTAssertEqual(localDelegate.receivedLines.last, ["abc", "def"])
    XCTAssertEqual(limitedFileSystem.offset(for: descriptor), 8)
  }

  func test_handleFileEvent_whenChunkNotUTF8_doesNotEmitLines() {
    fileSystem.files[path]?.append(Data([0xFF, 0xFE]))
    eventSource.trigger()

    XCTAssertTrue(delegate.receivedLines.isEmpty)
  }

  func test_start_whenOpenFails_translatesErrno() {
    let failingFileSystem = MockFileSystem()
    failingFileSystem.openFailures[path] = ENOENT
    let failingWatcher = FileWatcher(path: path, fileSystem: failingFileSystem)

    XCTAssertThrowsError(try failingWatcher.start()) { error in
      XCTAssertEqual(error as? FileWatcherError, .fileDeleted(path: path))
    }
  }

  func test_start_whenLseekFails_throwsDescriptorInvalid() {
    let failingFileSystem = MockFileSystem()
    failingFileSystem.overwriteFile(path, with: "data")
    failingFileSystem.lseekFailures[3] = EBADF
    let failingWatcher = FileWatcher(path: path, fileSystem: failingFileSystem)

    XCTAssertThrowsError(try failingWatcher.start()) { error in
      XCTAssertEqual(error as? FileWatcherError, .fileDescriptorInvalid)
    }
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

  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
    receivedLines.append(lines)
    linesExpectation?.fulfill()
  }

  func fileWatcher(
    _ watcher: FileWatching,
    didEncounterError error: FileWatcherError
  ) {
    receivedErrors.append(error)
    errorExpectation?.fulfill()
  }
}

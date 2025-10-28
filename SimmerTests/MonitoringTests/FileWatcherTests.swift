//
//  FileWatcherTests.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import XCTest
@testable import Simmer

final class FileWatcherTests: XCTestCase {
    private let testQueue = DispatchQueue(label: "com.simmer.tests.filewatcher")

    func test_fileWatcherDeliversLines_whenFileAppended() {
        let path = "/tmp/test.log"
        let fileSystem = MockFileSystem()
        fileSystem.simulateFileCreation(path: path)

        let source = MockFileSystemEventSource()
        let factory = MockFileSystemEventSourceFactory(source: source)

        let watcher = FileWatcher(
            path: path,
            fileSystem: fileSystem,
            queue: testQueue,
            sourceFactory: factory
        )

        let expectation = expectation(description: "delegate receives appended lines")
        let delegate = MockWatcherDelegate()
        delegate.onLines = { lines in
            XCTAssertEqual(lines, ["ERROR: test"])
            expectation.fulfill()
        }
        watcher.delegate = delegate

        watcher.startWatching()
        testQueue.sync {}

        fileSystem.simulateAppend(to: path, content: "ERROR: test\n")
        source.trigger(eventMask: [.write])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(source.resumeCallCount, 1)
        XCTAssertEqual(source.cancelCallCount, 0)
        XCTAssertEqual(factory.lastMask, [.write, .extend, .delete])
        watcher.stopWatching()
    }

    func test_fileWatcherEmitsDeletionError_whenFileDeleted() {
        let path = "/tmp/delete.log"
        let fileSystem = MockFileSystem()
        fileSystem.simulateFileCreation(path: path)

        let source = MockFileSystemEventSource()
        let factory = MockFileSystemEventSourceFactory(source: source)

        let watcher = FileWatcher(
            path: path,
            fileSystem: fileSystem,
            queue: testQueue,
            sourceFactory: factory
        )

        let expectation = expectation(description: "delegate receives deletion error")
        let delegate = MockWatcherDelegate()
        delegate.onError = { error in
            if case .fileDeleted(let receivedPath) = error {
                XCTAssertEqual(receivedPath, path)
                expectation.fulfill()
            } else {
                XCTFail("Unexpected error \(error)")
            }
        }
        watcher.delegate = delegate

        watcher.startWatching()
        testQueue.sync {}

        source.trigger(eventMask: [.delete])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(source.cancelCallCount, 1)
        watcher.stopWatching()
    }

    func test_fileWatcherReportsPermissionError_whenOpenFails() {
        let path = "/tmp/missing.log"
        let fileSystem = MockFileSystem()  // no file created -> open returns -1

        let source = MockFileSystemEventSource()
        let factory = MockFileSystemEventSourceFactory(source: source)

        let watcher = FileWatcher(
            path: path,
            fileSystem: fileSystem,
            queue: testQueue,
            sourceFactory: factory
        )

        let expectation = expectation(description: "delegate receives permission error")
        let delegate = MockWatcherDelegate()
        delegate.onError = { error in
            if case .permissionDenied(let receivedPath) = error {
                XCTAssertEqual(receivedPath, path)
                expectation.fulfill()
            } else {
                XCTFail("Unexpected error \(error)")
            }
        }
        watcher.delegate = delegate

        watcher.startWatching()
        testQueue.sync {}

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(factory.lastDescriptor)
        XCTAssertNil(factory.lastMask)
        watcher.stopWatching()
    }

    func test_fileWatcherReportsInvalidDescriptor_whenReadFails() {
        let path = "/tmp/invalid.log"
        let fileSystem = MockFileSystem()
        fileSystem.simulateFileCreation(path: path, content: "existing\n")

        let source = MockFileSystemEventSource()
        let factory = MockFileSystemEventSourceFactory(source: source)

        let watcher = FileWatcher(
            path: path,
            fileSystem: fileSystem,
            queue: testQueue,
            sourceFactory: factory
        )

        let expectation = expectation(description: "delegate receives invalid descriptor error")
        let delegate = MockWatcherDelegate()
        delegate.onError = { error in
            if case .fileDescriptorInvalid = error {
                expectation.fulfill()
            } else {
                XCTFail("Unexpected error \(error)")
            }
        }
        watcher.delegate = delegate

        watcher.startWatching()
        testQueue.sync {}

        fileSystem.invalidateDescriptor(for: path)
        source.trigger(eventMask: [.write])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(source.cancelCallCount, 1)
        watcher.stopWatching()
    }

    func test_fileWatcherDeliversIncrementalLines_whenRapidAppendsOccur() {
        let path = "/tmp/rapid.log"
        let fileSystem = MockFileSystem()
        fileSystem.simulateFileCreation(path: path)

        let source = MockFileSystemEventSource()
        let factory = MockFileSystemEventSourceFactory(source: source)

        let watcher = FileWatcher(
            path: path,
            fileSystem: fileSystem,
            queue: testQueue,
            sourceFactory: factory
        )

        let expectationFirst = expectation(description: "first append delivered")
        let expectationSecond = expectation(description: "second append delivered")

        let delegate = MockWatcherDelegate()
        var callbacks = 0
        delegate.onLines = { lines in
            callbacks += 1
            if callbacks == 1 {
                XCTAssertEqual(lines, ["first event"])
                expectationFirst.fulfill()
            } else if callbacks == 2 {
                XCTAssertEqual(lines, ["second event"])
                expectationSecond.fulfill()
            }
        }
        watcher.delegate = delegate

        watcher.startWatching()
        testQueue.sync {}

        fileSystem.simulateAppend(to: path, content: "first event\n")
        source.trigger(eventMask: [.write])

        fileSystem.simulateAppend(to: path, content: "second event\n")
        source.trigger(eventMask: [.extend])

        wait(for: [expectationFirst, expectationSecond], timeout: 1.0)
        XCTAssertEqual(callbacks, 2)
        watcher.stopWatching()
    }
}

private final class MockWatcherDelegate: FileWatcherDelegate {
    var onLines: (([String]) -> Void)?
    var onError: ((FileWatcherError) -> Void)?

    func fileWatcher(_ watcher: FileWatcher, didReadLines lines: [String]) {
        onLines?(lines)
    }

    func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcherError) {
        onError?(error)
    }
}

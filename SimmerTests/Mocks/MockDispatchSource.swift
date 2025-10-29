//
//  MockDispatchSource.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import Foundation
@testable import Simmer

/// Mock DispatchSource factory to drive FileWatcher tests deterministically.
internal final class MockFileSystemEventSource: FileSystemEventSource {
    private(set) var dataValue: DispatchSource.FileSystemEvent = []
    private var eventHandler: (() -> Void)?
    private var cancelHandler: (() -> Void)?

    private(set) var resumeCallCount = 0
    private(set) var cancelCallCount = 0

    var data: DispatchSource.FileSystemEvent {
        dataValue
    }

    func setEventHandler(handler: @escaping () -> Void) {
        eventHandler = handler
    }

    func setCancelHandler(handler: @escaping () -> Void) {
        cancelHandler = handler
    }

    func resume() {
        resumeCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
        cancelHandler?()
    }

    func trigger(eventMask: DispatchSource.FileSystemEvent) {
        dataValue = eventMask
        eventHandler?()
    }
}

internal final class MockFileSystemEventSourceFactory {
    private let source: MockFileSystemEventSource

    private(set) var lastDescriptor: Int32?
    private(set) var lastMask: DispatchSource.FileSystemEvent?

    init(source: MockFileSystemEventSource) {
        self.source = source
    }

    func makeSource(
        fileDescriptor: Int32,
        mask: DispatchSource.FileSystemEvent,
        queue: DispatchQueue
    ) -> FileSystemEventSource {
        lastDescriptor = fileDescriptor
        lastMask = mask
        return source
    }
}

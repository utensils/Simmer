//
//  FileWatcher.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Dispatch
import Foundation

protocol FileSystemEventSource: AnyObject {
    var data: DispatchSource.FileSystemEvent { get }
    func setEventHandler(handler: @escaping () -> Void)
    func setCancelHandler(handler: (() -> Void)?)
    func resume()
    func cancel()
}

protocol FileSystemEventSourceFactory {
    func makeSource(
        fileDescriptor: Int32,
        mask: DispatchSource.FileSystemEvent,
        queue: DispatchQueue
    ) -> FileSystemEventSource
}

struct DispatchSourceFactory: FileSystemEventSourceFactory {
    func makeSource(
        fileDescriptor: Int32,
        mask: DispatchSource.FileSystemEvent,
        queue: DispatchQueue
    ) -> FileSystemEventSource {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: mask,
            queue: queue
        )
        return DispatchFileSystemEventSource(source: source)
    }
}

final class DispatchFileSystemEventSource: FileSystemEventSource {
    private let source: DispatchSourceFileSystemObject

    init(source: DispatchSourceFileSystemObject) {
        self.source = source
    }

    var data: DispatchSource.FileSystemEvent {
        source.data
    }

    func setEventHandler(handler: @escaping () -> Void) {
        source.setEventHandler(handler: handler)
    }

    func setCancelHandler(handler: (() -> Void)?) {
        source.setCancelHandler(handler: handler)
    }

    func resume() {
        source.resume()
    }

    func cancel() {
        source.cancel()
    }
}

/// Monitors a single log file for new appended content using DispatchSource.
/// Per TECH_DESIGN.md: Uses DispatchSource.makeFileSystemObjectSource with .write and .extend masks.
class FileWatcher {
    let filePath: String
    weak var delegate: FileWatcherDelegate?

    private let fileSystem: FileSystemProtocol
    private let sourceFactory: FileSystemEventSourceFactory
    private var fileDescriptor: Int32?
    private var dispatchSource: FileSystemEventSource?
    private let queue: DispatchQueue

    init(
        path: String,
        fileSystem: FileSystemProtocol = RealFileSystem(),
        queue: DispatchQueue = DispatchQueue(label: "com.simmer.filewatcher", qos: .userInitiated),
        sourceFactory: FileSystemEventSourceFactory = DispatchSourceFactory()
    ) {
        self.filePath = path
        self.fileSystem = fileSystem
        self.queue = queue
        self.sourceFactory = sourceFactory
    }

    func startWatching() {
        queue.async { [weak self] in
            self?.openFileAndStartMonitoring()
        }
    }

    func stopWatching() {
        dispatchSource?.cancel()
        if let fd = fileDescriptor {
            _ = fileSystem.close(fd)
        }
        fileDescriptor = nil
        dispatchSource = nil
    }

    private func openFileAndStartMonitoring() {
        let fd = fileSystem.open(filePath, O_RDONLY)
        guard fd >= 0 else {
            notifyOnMain(error: .permissionDenied(path: filePath))
            return
        }

        fileDescriptor = fd

        // Seek to end of file to only read new content (FR-023).
        _ = fileSystem.lseek(fd, 0, SEEK_END)

        // Create DispatchSource for file monitoring.
        let source = sourceFactory.makeSource(
            fileDescriptor: fd,
            mask: [.write, .extend, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleFileEvent()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor {
                _ = self?.fileSystem.close(fd)
            }
        }

        dispatchSource = source
        source.resume()
    }

    private func handleFileEvent() {
        guard let fd = fileDescriptor,
              let source = dispatchSource else { return }

        let eventData = source.data

        if eventData.contains(.delete) {
            notifyOnMain(error: .fileDeleted(path: filePath))
            stopWatching()
            return
        }

        let (newLines, error) = readNewLines(from: fd)

        if let error {
            notifyOnMain(error: error)
            stopWatching()
            return
        }

        if !newLines.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.fileWatcher(self, didReadLines: newLines)
            }
        }
    }

    private func readNewLines(from fd: Int32) -> ([String], FileWatcherError?) {
        var lines: [String] = []
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var accumulatedData = Data()
        var encounteredError = false

        while true {
            let bytesRead = fileSystem.read(fd, &buffer, bufferSize)

            if bytesRead > 0 {
                accumulatedData.append(contentsOf: buffer.prefix(bytesRead))
                continue
            }

            if bytesRead == 0 {
                break
            }

            encounteredError = true
            break
        }

        if encounteredError {
            return ([], .fileDescriptorInvalid)
        }

        guard !accumulatedData.isEmpty else { return ([], nil) }

        if let content = String(data: accumulatedData, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }

        return (lines, nil)
    }

    deinit {
        stopWatching()
    }

    private func notifyOnMain(error: FileWatcherError) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.fileWatcher(self, didEncounterError: error)
        }
    }
}

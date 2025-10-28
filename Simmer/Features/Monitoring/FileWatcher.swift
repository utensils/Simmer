//
//  FileWatcher.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Monitors a single log file for new appended content using DispatchSource
/// Per TECH_DESIGN.md: Uses DispatchSource.makeFileSystemObjectSource with .write and .extend masks
class FileWatcher {
    let filePath: String
    weak var delegate: FileWatcherDelegate?

    private let fileSystem: FileSystemProtocol
    private var fileDescriptor: Int32?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var filePosition: off_t = 0
    private let queue: DispatchQueue

    init(path: String, fileSystem: FileSystemProtocol = RealFileSystem(), queue: DispatchQueue = DispatchQueue(label: "com.simmer.filewatcher", qos: .userInitiated)) {
        self.filePath = path
        self.fileSystem = fileSystem
        self.queue = queue
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
            delegate?.fileWatcher(self, didEncounterError: .permissionDenied(path: filePath))
            return
        }

        fileDescriptor = fd

        // Seek to end of file to only read new content (FR-023)
        filePosition = fileSystem.lseek(fd, 0, SEEK_END)

        // Create DispatchSource for file monitoring
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete],
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

        // Check if file was deleted
        if source.data.contains(.delete) {
            delegate?.fileWatcher(self, didEncounterError: .fileDeleted(path: filePath))
            stopWatching()
            return
        }

        // Read new content
        let newLines = readNewLines(from: fd)
        if !newLines.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.fileWatcher(self, didReadLines: newLines)
            }
        }
    }

    private func readNewLines(from fd: Int32) -> [String] {
        var lines: [String] = []
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        var accumulatedData = Data()

        while true {
            let bytesRead = fileSystem.read(fd, &buffer, bufferSize)
            guard bytesRead > 0 else { break }

            accumulatedData.append(contentsOf: buffer.prefix(bytesRead))
        }

        guard !accumulatedData.isEmpty else { return [] }

        if let content = String(data: accumulatedData, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }

        return lines
    }

    deinit {
        stopWatching()
    }
}

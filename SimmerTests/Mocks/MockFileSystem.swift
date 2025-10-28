//
//  MockFileSystem.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import Foundation
@testable import Simmer

/// Mock file system for testing FileWatcher without disk I/O
class MockFileSystem: FileSystemProtocol {
    private var files: [Int32: MockFile] = [:]
    private var nextFD: Int32 = 100
    private var pathToFD: [String: Int32] = [:]

    struct MockFile {
        var path: String
        var content: Data
        var position: Int = 0
        var isOpen: Bool = true
    }

    func simulateFileCreation(path: String, content: String = "") {
        let data = content.data(using: .utf8) ?? Data()
        let fd = nextFD
        nextFD += 1

        files[fd] = MockFile(path: path, content: data)
        pathToFD[path] = fd
    }

    func simulateAppend(to path: String, content: String) {
        guard let fd = pathToFD[path],
              var file = files[fd] else { return }

        let newData = content.data(using: .utf8) ?? Data()
        file.content.append(newData)
        files[fd] = file
    }

    func simulateFileDeletion(path: String) {
        if let fd = pathToFD[path] {
            files.removeValue(forKey: fd)
            pathToFD.removeValue(forKey: path)
        }
    }

    func invalidateDescriptor(for path: String) {
        guard let fd = pathToFD[path],
              var file = files[fd] else { return }
        file.isOpen = false
        files[fd] = file
    }

    func open(_ path: String, _ oflag: Int32) -> Int32 {
        if let fd = pathToFD[path] {
            return fd
        }

        // File doesn't exist
        return -1
    }

    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
        guard var file = files[fd], file.isOpen else {
            return -1
        }

        let availableBytes = file.content.count - file.position
        let bytesToRead = min(count, availableBytes)

        guard bytesToRead > 0 else { return 0 }

        let range = file.position..<(file.position + bytesToRead)
        file.content.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), from: range)

        file.position += bytesToRead
        files[fd] = file

        return bytesToRead
    }

    func close(_ fd: Int32) -> Int32 {
        guard var file = files[fd] else {
            return -1
        }

        file.isOpen = false
        files[fd] = file
        return 0
    }

    func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t {
        guard var file = files[fd] else {
            return -1
        }

        let newPosition: Int
        switch whence {
        case SEEK_SET:
            newPosition = Int(offset)
        case SEEK_CUR:
            newPosition = file.position + Int(offset)
        case SEEK_END:
            newPosition = file.content.count + Int(offset)
        default:
            return -1
        }

        file.position = max(0, min(newPosition, file.content.count))
        files[fd] = file

        return off_t(file.position)
    }
}

//
//  FileSystemProtocol.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Abstraction over POSIX file I/O for mocking in FileWatcher tests
/// Per contracts/internal-protocols.md
protocol FileSystemProtocol {
    /// Open file at path with flags, returns file descriptor or -1 on error
    func open(_ path: String, _ oflag: Int32) -> Int32

    /// Read bytes from file descriptor into buffer
    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int

    /// Close file descriptor
    func close(_ fd: Int32) -> Int32

    /// Get current file offset
    func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t
}

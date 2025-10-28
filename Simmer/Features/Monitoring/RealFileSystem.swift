//
//  RealFileSystem.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Production implementation of FileSystemProtocol wrapping POSIX file I/O
struct RealFileSystem: FileSystemProtocol {
    func open(_ path: String, _ oflag: Int32) -> Int32 {
        Darwin.open(path, oflag)
    }

    func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
        Darwin.read(fd, buffer, count)
    }

    func close(_ fd: Int32) -> Int32 {
        Darwin.close(fd)
    }

    func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t {
        Darwin.lseek(fd, offset, whence)
    }
}

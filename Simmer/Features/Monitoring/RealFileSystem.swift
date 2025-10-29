//
//  RealFileSystem.swift
//  Simmer
//
//  Production implementation of ``FileSystemProtocol`` backed by POSIX calls.
//

import Darwin
import Foundation

internal struct RealFileSystem: FileSystemProtocol {
  func open(_ path: String, _ oflag: Int32) -> Int32 {
    path.withCString { pointer in
      Darwin.open(pointer, oflag)
    }
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

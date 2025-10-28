//
//  FileSystemProtocol.swift
//  Simmer
//
//  Abstraction over POSIX file operations to enable deterministic tests.
//

import Foundation

/// Contracts the minimal file operations required by ``FileWatcher``.
protocol FileSystemProtocol {
  /// Opens a file descriptor for the provided path using the supplied flags.
  func open(_ path: String, _ oflag: Int32) -> Int32

  /// Reads up to `count` bytes from a file descriptor into `buffer`.
  func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int

  /// Closes an active file descriptor.
  func close(_ fd: Int32) -> Int32

  /// Adjusts or returns a file descriptor's offset.
  func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t
}

//
//  MockFileSystem.swift
//  SimmerTests
//
//  Test double for ``FileSystemProtocol`` that simulates POSIX semantics.
//

import Darwin
import Foundation
@testable import Simmer

internal final class MockFileSystem: FileSystemProtocol {
  private struct DescriptorState {
    let path: String
    var offset: off_t
  }

  private var descriptors: [Int32: DescriptorState] = [:]
  private var nextDescriptor: Int32 = 3

  /// Backing store keyed by absolute file path.
  var files: [String: Data] = [:]

  /// Paths that should fail to open with the supplied errno value.
  var openFailures: [String: Int32] = [:]

  /// Descriptors that should fail future read operations with the supplied errno value.
  var readFailures: [Int32: Int32] = [:]

  /// Descriptors that should fail to close with the supplied errno value.
  var closeFailures: [Int32: Int32] = [:]

  /// Descriptors that should fail to seek with the supplied errno value.
  var lseekFailures: [Int32: Int32] = [:]

  func open(_ path: String, _ oflag: Int32) -> Int32 {
    if let errnoValue = openFailures[path] {
      Darwin.errno = errnoValue
      return -1
    }

    if files[path] == nil {
      files[path] = Data()
    }

    let descriptor = nextDescriptor
    nextDescriptor += 1
    descriptors[descriptor] = DescriptorState(path: path, offset: 0)
    return descriptor
  }

  func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
    if let errnoValue = readFailures[fd] {
      Darwin.errno = errnoValue
      return -1
    }

    guard var state = descriptors[fd] else {
      Darwin.errno = EBADF
      return -1
    }

    guard let data = files[state.path] else {
      Darwin.errno = ENOENT
      return -1
    }

    let remaining = data.count - Int(state.offset)
    if remaining <= 0 {
      return 0
    }

    let length = min(count, remaining)
    let range = Int(state.offset)..<Int(state.offset) + length
    let slice = data.subdata(in: range)
    slice.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: length)
    state.offset += off_t(length)
    descriptors[fd] = state
    return length
  }

  func close(_ fd: Int32) -> Int32 {
    if let errnoValue = closeFailures[fd] {
      Darwin.errno = errnoValue
      return -1
    }

    guard descriptors.removeValue(forKey: fd) != nil else {
      Darwin.errno = EBADF
      return -1
    }

    return 0
  }

  func lseek(_ fd: Int32, _ offset: off_t, _ whence: Int32) -> off_t {
    if let errnoValue = lseekFailures[fd] {
      Darwin.errno = errnoValue
      return -1
    }

    guard var state = descriptors[fd] else {
      Darwin.errno = EBADF
      return -1
    }

    guard let data = files[state.path] else {
      Darwin.errno = ENOENT
      return -1
    }

    let newOffset: off_t
    switch whence {
    case SEEK_SET:
      newOffset = offset
    case SEEK_CUR:
      newOffset = state.offset + offset
    case SEEK_END:
      newOffset = off_t(data.count) + offset
    default:
      Darwin.errno = EINVAL
      return -1
    }

    if newOffset < 0 {
      Darwin.errno = EINVAL
      return -1
    }

    state.offset = newOffset
    descriptors[fd] = state
    return newOffset
  }
}

// MARK: - Test Helpers

extension MockFileSystem {
  /// Replaces the entire file contents for `path`.
  func overwriteFile(_ path: String, with string: String, encoding: String.Encoding = .utf8) {
    if let data = string.data(using: encoding) {
      files[path] = data
    } else {
      files[path] = Data()
    }
  }

  /// Appends content to the existing data backing `path`.
  func append(_ string: String, to path: String, encoding: String.Encoding = .utf8) {
    var data = files[path] ?? Data()
    if let chunk = string.data(using: encoding) {
      data.append(chunk)
    }
    files[path] = data
  }

  /// Removes the backing store for `path`, simulating file deletion.
  func deleteFile(at path: String) {
    files.removeValue(forKey: path)
  }

  /// Retrieves the current offset for a descriptor, useful for assertions.
  func offset(for fd: Int32) -> off_t? {
    descriptors[fd]?.offset
  }

  /// Returns the descriptor associated with a specific path, if one exists.
  func descriptor(forPath path: String) -> Int32? {
    descriptors.first { $0.value.path == path }?.key
  }
}

//
//  FileWatcher.swift
//  Simmer
//
//  Observes a single log file for appended content using DispatchSource.
//

import Darwin
import Foundation

internal protocol FileSystemEventSource: AnyObject {
  func setEventHandler(handler: @escaping () -> Void)
  func setCancelHandler(handler: @escaping () -> Void)
  func resume()
  func cancel()
}

internal final class DispatchSourceFileSystemWrapper: FileSystemEventSource {
  private let source: DispatchSourceFileSystemObject

  init(fileDescriptor: Int32, mask: DispatchSource.FileSystemEvent, queue: DispatchQueue) {
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: mask,
      queue: queue
    )
  }

  func setEventHandler(handler: @escaping () -> Void) {
    source.setEventHandler(handler: handler)
  }

  func setCancelHandler(handler: @escaping () -> Void) {
    source.setCancelHandler(handler: handler)
  }

  func resume() {
    source.resume()
  }

  func cancel() {
    source.cancel()
  }
}

internal final class FileWatcher: FileWatching {
  typealias SourceFactory = (Int32, DispatchSource.FileSystemEvent, DispatchQueue) -> FileSystemEventSource

  weak var delegate: FileWatcherDelegate?
  let path: String

  private let fileSystem: FileSystemProtocol
  private let queue: DispatchQueue
  private let sourceFactory: SourceFactory
  private let bufferSize: Int
  private let maxBytesPerEvent: Int
  private var source: FileSystemEventSource?
  private var fileDescriptor: Int32 = -1
  private var readOffset: off_t = 0
  private var remainder = ""
  private var isRunning = false

  init(
    path: String,
    fileSystem: FileSystemProtocol = RealFileSystem(),
    queue: DispatchQueue = DispatchQueue(label: "io.utensils.Simmer.FileWatcher"),
    bufferSize: Int = 4_096,
    maxBytesPerEvent: Int = 1_048_576, // 1MB limit to prevent memory pressure
    sourceFactory: @escaping SourceFactory = { fd, mask, queue in
      DispatchSourceFileSystemWrapper(fileDescriptor: fd, mask: mask, queue: queue)
    }
  ) {
    self.path = path
    self.fileSystem = fileSystem
    self.queue = queue
    self.bufferSize = bufferSize
    self.maxBytesPerEvent = maxBytesPerEvent
    self.sourceFactory = sourceFactory
  }

  deinit {
    stop()
  }

  func start() throws {
    guard !isRunning else { return }

    // Expand path to resolve tilde (~) and environment variables
    let expandedPath = PathExpander.expand(path)

    let descriptor = fileSystem.open(expandedPath, O_RDONLY)
    guard descriptor >= 0 else {
      throw mapErrnoToError(Darwin.errno)
    }
    fileDescriptor = descriptor

    let position = fileSystem.lseek(descriptor, 0, SEEK_END)
    guard position >= 0 else {
      _ = fileSystem.close(descriptor)
      throw FileWatcherError.fileDescriptorInvalid
    }
    readOffset = position

    let eventMask: DispatchSource.FileSystemEvent = [.write, .extend, .delete]
    let eventSource = sourceFactory(descriptor, eventMask, queue)
    eventSource.setEventHandler { [weak self] in
      self?.handleFileEvent()
    }
    eventSource.setCancelHandler { [weak self] in
      self?.cleanup()
    }
    eventSource.resume()

    source = eventSource
    isRunning = true
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    source?.cancel()
    source = nil
    cleanup()
  }

  private func handleFileEvent() {
    guard isRunning else {
      return
    }

    guard fileDescriptor >= 0 else {
      delegate?.fileWatcher(
        self,
        didEncounterError: .fileDescriptorInvalid
      )
      return
    }

    var collectedData = Data()

    let seekResult = fileSystem.lseek(fileDescriptor, readOffset, SEEK_SET)
    if seekResult == -1 {
      delegate?.fileWatcher(
        self,
        didEncounterError: mapErrnoToError(Darwin.errno)
      )
      stop()
      return
    }

    while true {
      // Stop reading if we've hit the per-event limit to prevent memory pressure
      if collectedData.count >= maxBytesPerEvent {
        break
      }

      var buffer = Data(count: bufferSize)
      let bytesRead = buffer.withUnsafeMutableBytes { pointer -> Int in
        guard let baseAddress = pointer.baseAddress else {
          return 0
        }
        return fileSystem.read(fileDescriptor, baseAddress, bufferSize)
      }

      if bytesRead > 0 {
        readOffset += off_t(bytesRead)
        collectedData.append(buffer.prefix(bytesRead))
        if bytesRead < bufferSize {
          break
        }
      } else if bytesRead == 0 {
        break
      } else {
        delegate?.fileWatcher(
          self,
          didEncounterError: mapErrnoToError(Darwin.errno)
        )
        stop()
        return
      }
    }

    guard !collectedData.isEmpty else {
      return
    }

    emitLines(from: collectedData)
  }

  private func emitLines(from data: Data) {
    guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else {
      return
    }

    let combined = remainder + chunk
    var segments = combined.components(separatedBy: "\n")

    if combined.last != "\n" {
      remainder = segments.removeLast()
    } else {
      remainder = ""
    }

    let lines = segments.filter { !$0.isEmpty }
    guard !lines.isEmpty else { return }

    delegate?.fileWatcher(self, didReadLines: lines)
  }

  private func cleanup() {
    if fileDescriptor >= 0 {
      _ = fileSystem.close(fileDescriptor)
      fileDescriptor = -1
    }
    remainder = ""
    readOffset = 0
  }

  private func mapErrnoToError(_ value: Int32) -> FileWatcherError {
    switch value {
    case ENOENT:
      return .fileDeleted(path: path)

    case EACCES:
      return .permissionDenied(path: path)

    case EPERM:
      return .permissionDenied(path: path)

    case EBADF:
      return .fileDescriptorInvalid

    default:
      return .fileDescriptorInvalid
    }
  }
}

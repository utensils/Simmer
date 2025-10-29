//
//  FileAccessManager.swift
//  Simmer
//
//  Simplified file access for non-sandboxed apps.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Errors that can occur during file access operations.
internal enum FileAccessError: Error, LocalizedError, Equatable {
  case userCancelled
  case fileNotAccessible(path: String)

  var errorDescription: String? {
    switch self {
    case .userCancelled:
      return "File selection was cancelled"
    case let .fileNotAccessible(path):
      return "Cannot access \"\(path)\""
    }
  }
}

/// Protocol for file selection via file picker (primarily for testing).
@MainActor
internal protocol FileAccessManaging: AnyObject {
  func requestAccess(allowedFileTypes: [String]?) throws -> URL
}

/// Manages NSOpenPanel interactions for selecting log files in a non-sandboxed context.
@MainActor
internal final class FileAccessManager: FileAccessManaging {
  private let panelFactory: () -> NSOpenPanel

  init(panelFactory: @escaping () -> NSOpenPanel = { NSOpenPanel() }) {
    self.panelFactory = panelFactory
  }

  /// Requests the user to select a file via an open panel.
  /// - Parameter allowedFileTypes: Allowed filename extensions, such as `["log"]`.
  /// - Returns: URL of the selected file.
  /// - Throws: `FileAccessError.userCancelled` if the user cancels selection.
  func requestAccess(allowedFileTypes: [String]? = nil) throws -> URL {
    let panel = self.panelFactory()
    panel.title = "Select Log File"
    panel.message = "Choose a log file to monitor"
    panel.prompt = "Select"
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.canCreateDirectories = false

    if let types = allowedFileTypes {
      panel.allowedContentTypes = types.compactMap { ext in
        UTType(filenameExtension: ext)
      }
    }

    let response = panel.runModal()
    guard response == .OK, let url = panel.url else {
      throw FileAccessError.userCancelled
    }

    guard FileManager.default.isReadableFile(atPath: url.path) else {
      throw FileAccessError.fileNotAccessible(path: url.path)
    }

    return url
  }
}

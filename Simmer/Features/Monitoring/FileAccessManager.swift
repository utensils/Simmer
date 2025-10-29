//
//  FileAccessManager.swift
//  Simmer
//
//  Simplified file access for non-sandboxed apps.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Errors that can occur during file access operations
enum FileAccessError: Error, LocalizedError, Equatable {
    case userCancelled
    case fileNotAccessible(path: String)

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "File selection was cancelled"
        case .fileNotAccessible(let path):
            return "Cannot access \"\(path)\""
        }
    }
}

/// Protocol for file access manager (for testing)
protocol FileAccessManaging: AnyObject {
    func requestAccess(allowedFileTypes: [String]?) throws -> URL
    func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool)
    func refreshStaleBookmark(_ bookmark: FileBookmark) throws -> FileBookmark
}

/// Simplified file access manager for non-sandboxed apps
@MainActor
final class FileAccessManager: FileAccessManaging {
    /// Requests user to select a file via file picker
    /// - Parameter allowedFileTypes: Optional array of allowed file extensions (e.g., ["log", "txt"])
    /// - Returns: URL of the selected file
    /// - Throws: FileAccessError if user cancels
    func requestAccess(allowedFileTypes: [String]? = nil) throws -> URL {
        let panel = NSOpenPanel()
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

        return url
    }

    func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool) {
        let url = URL(fileURLWithPath: bookmark.filePath)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileAccessError.fileNotAccessible(path: url.path)
        }
        return (url, bookmark.isStale)
    }

    func refreshStaleBookmark(_ bookmark: FileBookmark) throws -> FileBookmark {
        var refreshed = bookmark
        refreshed.isStale = false
        return refreshed
    }
}

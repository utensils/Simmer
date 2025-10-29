//
//  FileAccessManager.swift
//  Simmer
//
//  Manages security-scoped bookmarks for sandboxed file access.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Errors that can occur during file access operations
enum FileAccessError: Error, LocalizedError, Equatable {
    case userCancelled
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case fileNotAccessible(path: String)
    case bookmarkDataInvalid

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "File selection was cancelled"
        case .bookmarkCreationFailed:
            return "Failed to create security-scoped bookmark. Select the file again to grant access."
        case .bookmarkResolutionFailed:
            return "Failed to resolve security-scoped bookmark"
        case .fileNotAccessible(let path):
            return """
            Simmer cannot access “\(path)”. Use the Choose… button to select the file so macOS can grant permission.
            """
        case .bookmarkDataInvalid:
            return "Bookmark data is invalid or corrupted"
        }
    }
}

/// Protocol abstraction so consumers (e.g. ``LogMonitor``) can mock bookmark operations in tests.
protocol FileAccessManaging: AnyObject {
    func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool)
    func refreshStaleBookmark(_ bookmark: FileBookmark) throws -> FileBookmark
}

/// Encapsulates security-scoped bookmark data for sandboxed file access
struct FileBookmark: Codable, Equatable {
    let bookmarkData: Data
    let filePath: String
    var isStale: Bool

    init(bookmarkData: Data, filePath: String, isStale: Bool = false) {
        self.bookmarkData = bookmarkData
        self.filePath = filePath
        self.isStale = isStale
    }
}

/// Manages security-scoped file access for sandboxed macOS apps
@MainActor
final class FileAccessManager {
    /// Requests user to select a file and creates a security-scoped bookmark
    /// - Parameter allowedFileTypes: Optional array of allowed file extensions (e.g., ["log", "txt"])
    /// - Returns: FileBookmark containing the security-scoped bookmark data
    /// - Throws: FileAccessError if user cancels or bookmark creation fails
    func requestAccess(allowedFileTypes: [String]? = nil) throws -> FileBookmark {
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

        return try createBookmark(for: url)
    }

    /// Creates a security-scoped bookmark for the given URL
    /// - Parameter url: The file URL to create a bookmark for (typically from NSOpenPanel)
    /// - Returns: FileBookmark containing the security-scoped bookmark data
    /// - Throws: FileAccessError if bookmark creation fails
    func createBookmark(for url: URL) throws -> FileBookmark {
        let options: URL.BookmarkCreationOptions
        if #available(macOS 13, *) {
            options = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        } else {
            options = [.withSecurityScope]
        }

        let attemptBookmark = {
            try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        do {
            let data = try attemptBookmark()
            return FileBookmark(bookmarkData: data, filePath: url.path, isStale: false)
        } catch {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try attemptBookmark()
                return FileBookmark(bookmarkData: data, filePath: url.path, isStale: false)
            } catch {
                if !FileManager.default.isReadableFile(atPath: url.path) || !hasAccess {
                    throw FileAccessError.fileNotAccessible(path: url.path)
                }
                throw FileAccessError.bookmarkCreationFailed
            }
        }
    }

    /// Resolves a security-scoped bookmark to access the file
    /// - Parameter bookmark: The FileBookmark to resolve
    /// - Returns: Tuple of (URL, isStale) where URL is the resolved file URL
    /// - Throws: FileAccessError if resolution fails
    func resolveBookmark(_ bookmark: FileBookmark) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark.bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw FileAccessError.bookmarkResolutionFailed
        }

        return (url, isStale)
    }

    /// Accesses a file using a security-scoped bookmark and executes a closure
    /// - Parameters:
    ///   - bookmark: The FileBookmark to use for access
    ///   - handler: Closure that receives the resolved URL and stale flag
    /// - Throws: FileAccessError if resolution fails or handler throws
    func accessFile(
        with bookmark: FileBookmark,
        handler: (URL, Bool) throws -> Void
    ) throws {
        let (url, isStale) = try resolveBookmark(bookmark)

        guard url.startAccessingSecurityScopedResource() else {
            throw FileAccessError.fileNotAccessible(path: url.path)
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        try handler(url, isStale)
    }

    /// Re-requests access for a stale bookmark
    /// - Parameter oldBookmark: The stale bookmark to refresh
    /// - Returns: New FileBookmark with updated security scope
    /// - Throws: FileAccessError if user cancels or creation fails
    func refreshStaleBookmark(_ oldBookmark: FileBookmark) throws -> FileBookmark {
        // Try to use the old path as a hint
        let panel = NSOpenPanel()
        panel.title = "File Access Required"
        panel.message = "The file '\(oldBookmark.filePath)' needs to be selected again for continued access."
        panel.prompt = "Grant Access"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Try to navigate to the old file location if it exists
        let oldURL = URL(fileURLWithPath: oldBookmark.filePath)
        if FileManager.default.fileExists(atPath: oldBookmark.filePath) {
            panel.directoryURL = oldURL.deletingLastPathComponent()
            panel.nameFieldStringValue = oldURL.lastPathComponent
        }

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            throw FileAccessError.userCancelled
        }

        return try createBookmark(for: url)
    }

    /// Validates that a bookmark can still be resolved
    /// - Parameter bookmark: The bookmark to validate
    /// - Returns: True if bookmark is valid and can be resolved
    func isValid(_ bookmark: FileBookmark) -> Bool {
        do {
            let (_, _) = try resolveBookmark(bookmark)
            return true
        } catch {
            return false
        }
    }
}

extension FileAccessManager: FileAccessManaging {}

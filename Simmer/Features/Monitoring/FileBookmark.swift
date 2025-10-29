//
//  FileBookmark.swift
//  Simmer
//
//  Lightweight security bookmark placeholder for non-sandboxed builds.
//

import Foundation

/// Represents a stored reference to a user-selected file.
struct FileBookmark: Codable, Equatable {
  var bookmarkData: Data
  var filePath: String
  var isStale: Bool

  init(bookmarkData: Data = Data(), filePath: String, isStale: Bool = false) {
    self.bookmarkData = bookmarkData
    self.filePath = filePath
    self.isStale = isStale
  }
}

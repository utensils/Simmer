//
//  ConfigurationSnapshot.swift
//  Simmer
//
//  Shared snapshot structure for exporting and importing pattern configurations.
//

import Foundation

/// Serializable payload representing an exported set of log pattern configurations.
struct ConfigurationSnapshot: Codable {
  static let currentVersion = 1

  let version: Int
  let exportedAt: Date
  let patterns: [LogPattern]

  init(version: Int = ConfigurationSnapshot.currentVersion, exportedAt: Date = Date(), patterns: [LogPattern]) {
    self.version = version
    self.exportedAt = exportedAt
    self.patterns = patterns
  }
}

//
//  ConfigurationStoreProtocol.swift
//  Simmer
//
//  Abstracts persistence for log pattern configurations.
//

import Foundation

/// Describes persistence capabilities used by the monitoring coordinator.
internal protocol ConfigurationStoreProtocol {
  /// Loads all stored log patterns; returns an empty array when nothing is persisted.
  func loadPatterns() -> [LogPattern]

  /// Persists the supplied collection of patterns, overwriting previous state.
  func savePatterns(_ patterns: [LogPattern]) throws

  /// Removes the pattern with a matching identifier.
  func deletePattern(id: UUID) throws

  /// Updates an existing pattern with new metadata.
  func updatePattern(_ pattern: LogPattern) throws
}

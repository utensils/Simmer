//
//  InMemoryStore.swift
//  SimmerTests
//
//  Ephemeral ``ConfigurationStoreProtocol`` implementation for unit tests.
//

import Foundation
@testable import Simmer

final class InMemoryStore: ConfigurationStoreProtocol {
  private var storage: [LogPattern]

  init(initialPatterns: [LogPattern] = []) {
    storage = initialPatterns
  }

  func loadPatterns() -> [LogPattern] {
    storage
  }

  func savePatterns(_ patterns: [LogPattern]) throws {
    storage = patterns
  }

  func deletePattern(id: UUID) throws {
    let initialCount = storage.count
    storage.removeAll { $0.id == id }
    if storage.count == initialCount {
      throw ConfigurationStoreError.patternNotFound
    }
  }

  func updatePattern(_ pattern: LogPattern) throws {
    guard let index = storage.firstIndex(where: { $0.id == pattern.id }) else {
      throw ConfigurationStoreError.patternNotFound
    }
    storage[index] = pattern
  }
}

//
//  ConfigurationStore.swift
//  Simmer
//
//  UserDefaults-backed implementation of ``ConfigurationStoreProtocol``.
//

import Foundation

internal enum ConfigurationStoreError: Error, Equatable {
  case encodingFailed
  case decodingFailed
  case patternNotFound
}

internal struct ConfigurationStore: ConfigurationStoreProtocol {
  private let patternsKey = "patterns"
  private let userDefaults: UserDefaults
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    userDefaults: UserDefaults = .standard,
    encoder: JSONEncoder = JSONEncoder(),
    decoder: JSONDecoder = JSONDecoder()
  ) {
    self.userDefaults = userDefaults
    self.encoder = encoder
    self.decoder = decoder
  }

  func loadPatterns() -> [LogPattern] {
    guard let data = userDefaults.data(forKey: patternsKey) else {
      return []
    }

    do {
      return try decoder.decode([LogPattern].self, from: data)
    } catch {
      // Remove corrupt persisted value to unblock future writes.
      userDefaults.removeObject(forKey: patternsKey)
      return []
    }
  }

  func savePatterns(_ patterns: [LogPattern]) throws {
    do {
      let data = try encoder.encode(patterns)
      userDefaults.set(data, forKey: patternsKey)
    } catch {
      throw ConfigurationStoreError.encodingFailed
    }
  }

  func deletePattern(id: UUID) throws {
    var patterns = loadPatterns()
    let originalCount = patterns.count
    patterns.removeAll { $0.id == id }
    guard patterns.count < originalCount else {
      throw ConfigurationStoreError.patternNotFound
    }
    try savePatterns(patterns)
  }

  func updatePattern(_ pattern: LogPattern) throws {
    var patterns = loadPatterns()
    guard let index = patterns.firstIndex(where: { $0.id == pattern.id }) else {
      throw ConfigurationStoreError.patternNotFound
    }
    patterns[index] = pattern
    try savePatterns(patterns)
  }
}

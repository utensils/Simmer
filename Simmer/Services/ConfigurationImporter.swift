//
//  ConfigurationImporter.swift
//  Simmer
//
//  Loads pattern configurations from exported JSON, performing validation before activation.
//

import Foundation

enum ConfigurationImportError: LocalizedError {
  case failedToRead(underlying: Error)
  case decodingFailed(underlying: Error)
  case unsupportedVersion(Int)
  case validationFailed(messages: [String])

  var errorDescription: String? {
    switch self {
    case .failedToRead(let underlying):
      return "Failed to open configuration: \(underlying.localizedDescription)"
    case .decodingFailed(let underlying):
      return "Configuration file is invalid: \(underlying.localizedDescription)"
    case .unsupportedVersion(let version):
      return "Configuration version \(version) is not supported."
    case .validationFailed(let messages):
      return messages.joined(separator: "\n")
    }
  }
}

protocol ConfigurationImporting {
  func importPatterns(from url: URL) throws -> [LogPattern]
}

struct ConfigurationImporter: ConfigurationImporting {
  private let maxPatternCount = 20
  private let patternLimitMessage = "Maximum 20 patterns supported"
  private let decoder: JSONDecoder

  init(decoder: JSONDecoder = JSONDecoder()) {
    self.decoder = decoder
    self.decoder.dateDecodingStrategy = .iso8601
  }

  func importPatterns(from url: URL) throws -> [LogPattern] {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw ConfigurationImportError.failedToRead(underlying: error)
    }

    let snapshot: ConfigurationSnapshot
    do {
      snapshot = try decoder.decode(ConfigurationSnapshot.self, from: data)
    } catch {
      throw ConfigurationImportError.decodingFailed(underlying: error)
    }

    guard snapshot.version == ConfigurationSnapshot.currentVersion else {
      throw ConfigurationImportError.unsupportedVersion(snapshot.version)
    }

    try validate(patterns: snapshot.patterns)
    return snapshot.patterns
  }

  private func validate(patterns: [LogPattern]) throws {
    var issues: [String] = []

    if patterns.count > maxPatternCount {
      issues.append(patternLimitMessage)
    }

    var seenIDs = Set<UUID>()
    for (index, pattern) in patterns.enumerated() {
      let humanIndex = index + 1
      if pattern.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Pattern #\(humanIndex) has an empty name.")
      }

      if pattern.logPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Pattern #\(humanIndex) has an empty log path.")
      }

      if seenIDs.contains(pattern.id) {
        issues.append("Pattern #\(humanIndex) duplicates an existing ID \(pattern.id).")
      } else {
        seenIDs.insert(pattern.id)
      }

      do {
        _ = try NSRegularExpression(pattern: pattern.regex)
      } catch {
        issues.append("Pattern '#\(pattern.name)' has invalid regex: \(error.localizedDescription)")
      }
    }

    if !issues.isEmpty {
      throw ConfigurationImportError.validationFailed(messages: issues)
    }
  }
}

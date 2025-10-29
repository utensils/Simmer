//
//  ConfigurationExporter.swift
//  Simmer
//
//  Writes pattern configurations to JSON for sharing and backups.
//

import Foundation

enum ConfigurationExportError: LocalizedError {
  case writeFailed(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .writeFailed(let underlying):
      return "Failed to export patterns: \(underlying.localizedDescription)"
    }
  }
}

protocol ConfigurationExporting {
  func export(patterns: [LogPattern], to url: URL) throws
}

struct ConfigurationExporter: ConfigurationExporting {
  private let encoder: JSONEncoder
  private let dateProvider: () -> Date

  init(
    encoder: JSONEncoder = JSONEncoder(),
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.encoder = encoder
    self.dateProvider = dateProvider
    self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder.dateEncodingStrategy = .iso8601
  }

  func export(patterns: [LogPattern], to url: URL) throws {
    let snapshot = ConfigurationSnapshot(exportedAt: dateProvider(), patterns: patterns)
    do {
      let data = try encoder.encode(snapshot)
      try data.write(to: url, options: .atomic)
    } catch {
      throw ConfigurationExportError.writeFailed(underlying: error)
    }
  }
}

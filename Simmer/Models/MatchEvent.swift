//
//  MatchEvent.swift
//  Simmer
//
//  Captures metadata for a single detected pattern match.
//

import Foundation

/// Immutable record describing a pattern match occurrence.
internal struct MatchEvent: Codable, Identifiable, Equatable {
  let id: UUID
  let patternID: UUID
  let patternName: String
  let timestamp: Date
  let matchedLine: String
  let lineNumber: Int
  let filePath: String
  let priority: Int

  init(
    id: UUID = UUID(),
    patternID: UUID,
    patternName: String,
    timestamp: Date = Date(),
    matchedLine: String,
    lineNumber: Int,
    filePath: String,
    priority: Int
  ) {
    let truncatedLine = matchedLine.count > 200
      ? String(matchedLine.prefix(200)) + "..."
      : matchedLine

    self.id = id
    self.patternID = patternID
    self.patternName = patternName
    self.timestamp = timestamp
    self.matchedLine = truncatedLine
    self.lineNumber = lineNumber
    self.filePath = filePath
    self.priority = priority
  }
}

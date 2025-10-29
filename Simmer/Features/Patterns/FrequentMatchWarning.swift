//
//  FrequentMatchWarning.swift
//  Simmer
//
//  Captures metadata for high-frequency match streaks so the UI can surface warnings.
//

import Foundation

/// Describes a warning when a pattern matches excessively, indicating the regex may be too broad.
internal struct FrequentMatchWarning: Identifiable, Equatable {
  let id: UUID
  let patternID: UUID
  let patternName: String
  let message: String
  let triggeredAt: Date

  init(patternID: UUID, patternName: String, triggeredAt: Date = Date()) {
    self.id = patternID
    self.patternID = patternID
    self.patternName = patternName
    self.triggeredAt = triggeredAt
    self.message =
      "Pattern '\(patternName)' matching frequently - consider refining regex"
  }
}

//
//  LogPattern.swift
//  Simmer
//
//  Persists a single user-defined log monitoring rule.
//

import Foundation

/// Represents a monitoring rule pairing a regex with file metadata.
struct LogPattern: Codable, Identifiable, Equatable {
  let id: UUID
  var name: String
  var regex: String
  var logPath: String
  var color: CodableColor
  var animationStyle: AnimationStyle
  var enabled: Bool

  init(
    id: UUID = UUID(),
    name: String,
    regex: String,
    logPath: String,
    color: CodableColor,
    animationStyle: AnimationStyle = .glow,
    enabled: Bool = true
  ) {
    self.id = id
    self.name = name
    self.regex = regex
    self.logPath = logPath
    self.color = color
    self.animationStyle = animationStyle
    self.enabled = enabled
  }
}

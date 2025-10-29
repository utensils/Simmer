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

  /// Cached compiled regex - not persisted, computed on demand
  private var _compiledRegex: NSRegularExpression?

  init(
    id: UUID = UUID(),
    name: String,
    regex: String,
    logPath: String,
    color: CodableColor,
    animationStyle: AnimationStyle = .glow,
    enabled: Bool = true,
    precompileRegex: Bool = true
  ) {
    self.id = id
    self.name = name
    self.regex = regex
    self.logPath = logPath
    self.color = color
    self.animationStyle = animationStyle
    self.enabled = enabled
    if precompileRegex {
      self._compiledRegex = try? NSRegularExpression(pattern: regex, options: [])
    } else {
      self._compiledRegex = nil
    }
  }

  /// Returns the pre-compiled regex, compiling if needed
  /// - Returns: Compiled NSRegularExpression, or nil if regex is invalid
  func compiledRegex() -> NSRegularExpression? {
    if let cached = _compiledRegex {
      return cached
    }
    return try? NSRegularExpression(pattern: regex, options: [])
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case id, name, regex, logPath, color, animationStyle, enabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    regex = try container.decode(String.self, forKey: .regex)
    logPath = try container.decode(String.self, forKey: .logPath)
    color = try container.decode(CodableColor.self, forKey: .color)
    animationStyle = try container.decode(AnimationStyle.self, forKey: .animationStyle)
    enabled = try container.decode(Bool.self, forKey: .enabled)

    // Pre-compile regex on decode
    self._compiledRegex = try? NSRegularExpression(pattern: regex, options: [])
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(regex, forKey: .regex)
    try container.encode(logPath, forKey: .logPath)
    try container.encode(color, forKey: .color)
    try container.encode(animationStyle, forKey: .animationStyle)
    try container.encode(enabled, forKey: .enabled)
    // _compiledRegex is not encoded - will be recompiled on decode
  }
}

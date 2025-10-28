//
//  LogPattern.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Represents a user-configured monitoring rule mapping regex pattern to log file
/// Per data-model.md: Complete pattern configuration with validation rules
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

    /// Validates pattern meets FR-011 requirements
    var isValid: Bool {
        !name.isEmpty &&
        name.count <= 50 &&
        !regex.isEmpty &&
        !logPath.isEmpty
    }
}

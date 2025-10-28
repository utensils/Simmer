//
//  AnimationStyle.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Visual feedback styles for menu bar icon animations
/// Per data-model.md: glow (2s), pulse (1.5s), blink (0.5s)
enum AnimationStyle: String, Codable, CaseIterable {
    case glow
    case pulse
    case blink

    /// Animation cycle duration in seconds
    var cycleDuration: TimeInterval {
        switch self {
        case .glow:
            return 2.0
        case .pulse:
            return 1.5
        case .blink:
            return 0.5
        }
    }
}

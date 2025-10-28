//
//  IconAnimationState.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Represents current runtime state of menu bar icon animation system
/// Per data-model.md: idle or animating with style and color
enum IconAnimationState: Equatable {
    case idle
    case animating(style: AnimationStyle, color: CodableColor)

    /// Returns true if currently animating
    var isAnimating: Bool {
        if case .animating = self {
            return true
        }
        return false
    }
}

//
//  IconAnimationState.swift
//  Simmer
//
//  Represents the current menu bar animation lifecycle state.
//

import Foundation

/// Runtime state for the menu bar icon animation system.
internal enum IconAnimationState: Equatable {
  case idle

  case animating(style: AnimationStyle, color: CodableColor)
}

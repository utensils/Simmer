//
//  IconAnimationFrameCalculator.swift
//  Simmer
//
//  Computes animation frame parameters for menu bar icon styles.
//

import CoreGraphics
import Foundation

internal struct IconAnimationFrameParameters: Equatable {
  let scale: CGFloat
  let opacity: CGFloat
  let visible: Bool

  static let idle = IconAnimationFrameParameters(scale: 1.0, opacity: 1.0, visible: true)
}

internal struct IconAnimationFrameCalculator {
  func parameters(for style: AnimationStyle, elapsed: TimeInterval) -> IconAnimationFrameParameters {
    switch style {
    case .glow:
      let cycle = normalizedCycle(
        elapsed: elapsed,
        duration: AnimationConstants.glowCycleDuration
      )
      let opacity = AnimationConstants.glowMinimumOpacity +
        cycle * AnimationConstants.glowOpacityRange
      return IconAnimationFrameParameters(scale: 1.0, opacity: opacity, visible: true)

    case .pulse:
      let cycle = normalizedCycle(
        elapsed: elapsed,
        duration: AnimationConstants.pulseCycleDuration
      )
      let scale = AnimationConstants.pulseBaseScale +
        cycle * AnimationConstants.pulseScaleAmplitude
      let opacity = AnimationConstants.pulseBaseOpacity +
        cycle * AnimationConstants.pulseOpacityRange
      return IconAnimationFrameParameters(scale: scale, opacity: opacity, visible: true)

    case .blink:
      let toggle = Int((elapsed / AnimationConstants.blinkInterval).rounded(.down)) % 2 == 0
      return IconAnimationFrameParameters(scale: 1.0, opacity: toggle ? 1.0 : 0.0, visible: toggle)
    }
  }

  private func normalizedCycle(elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
    let position = elapsed.truncatingRemainder(dividingBy: duration) / duration
    let normalized: Double
    if position <= 0.5 {
      normalized = position / 0.5
    } else {
      normalized = 1.0 - ((position - 0.5) / 0.5)
    }
    return CGFloat(max(0.0, min(1.0, normalized)))
  }

  private enum AnimationConstants {
    static let glowCycleDuration: TimeInterval = 2.0
    static let glowMinimumOpacity: CGFloat = 0.5
    static let glowOpacityRange: CGFloat = 0.5

    static let pulseCycleDuration: TimeInterval = 1.5
    static let pulseBaseScale: CGFloat = 1.0
    static let pulseScaleAmplitude: CGFloat = 0.15
    static let pulseBaseOpacity: CGFloat = 0.85
    static let pulseOpacityRange: CGFloat = 0.15

    static let blinkInterval: TimeInterval = 0.5
  }
}

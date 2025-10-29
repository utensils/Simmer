//
//  CodableColor.swift
//  Simmer
//
//  Codable wrapper that preserves NSColor information for persistence.
//

import AppKit
import SwiftUI

/// Encapsulates RGBA components so colors can be encoded and decoded safely.
internal struct CodableColor: Codable, Equatable {
  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  /// Creates a color from normalized RGBA components, clamping inputs to 0...1.
  init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
    self.red = Self.clamp(red)
    self.green = Self.clamp(green)
    self.blue = Self.clamp(blue)
    self.alpha = Self.clamp(alpha)
  }

  /// Creates a codable color from an existing NSColor instance.
  init(nsColor: NSColor) {
    let calibrated = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
    self.init(
      red: calibrated.redComponent,
      green: calibrated.greenComponent,
      blue: calibrated.blueComponent,
      alpha: calibrated.alphaComponent
    )
  }

  /// Builds an NSColor matching the stored component values.
  func toNSColor() -> NSColor {
    NSColor(
      calibratedRed: red,
      green: green,
      blue: blue,
      alpha: alpha
    )
  }

  /// Builds a SwiftUI Color matching the stored component values.
  func toColor() -> Color {
    Color(
      red: red,
      green: green,
      blue: blue,
      opacity: alpha
    )
  }

  private static func clamp(_ value: Double) -> Double {
    min(max(value, 0.0), 1.0)
  }
}

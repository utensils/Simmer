//
//  CodableColor.swift
//  Simmer
//
//  Created on 2025-10-28
//

import AppKit
import SwiftUI

/// Wrapper for NSColor/Color to enable Codable serialization of RGB values
/// Per data-model.md: RGB components 0.0-1.0 range
struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        // Clamp RGB components to 0.0-1.0 range per data-model.md
        self.red = min(max(red, 0.0), 1.0)
        self.green = min(max(green, 0.0), 1.0)
        self.blue = min(max(blue, 0.0), 1.0)
        self.alpha = min(max(alpha, 0.0), 1.0)
    }

    init(nsColor: NSColor) {
        // Convert to RGB color space if needed
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
            return
        }
        self.init(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
    }

    func toNSColor() -> NSColor {
        NSColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    func toColor() -> Color {
        Color(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
}

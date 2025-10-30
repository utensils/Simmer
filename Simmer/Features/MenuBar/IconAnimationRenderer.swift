//
//  IconAnimationRenderer.swift
//  Simmer
//
//  Renders menu bar icon frames using Core Graphics.
//

import AppKit

internal struct IconAnimationRenderer {
  private let iconSize: CGFloat

  init(iconSize: CGFloat) {
    self.iconSize = iconSize
  }

  func idleIcon(color: NSColor = IconAnimationRenderer.defaultIdleColor) -> NSImage {
    renderIcon(color: color, parameters: .idle)
  }

  func renderIcon(color: NSColor, parameters: IconAnimationFrameParameters) -> NSImage {
    let dimension = CGSize(width: iconSize, height: iconSize)
    let image = NSImage(size: dimension)

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
      return image
    }

    context.clear(CGRect(origin: .zero, size: dimension))

    let baseDiameter = iconSize * 0.6 * parameters.scale
    let origin = (iconSize - baseDiameter) / 2.0
    let rect = CGRect(x: origin, y: origin, width: baseDiameter, height: baseDiameter)

    guard parameters.opacity > 0 else {
      return image
    }

    let shadowColor = color.withAlphaComponent(parameters.opacity * 0.6).cgColor
    context.setShadow(
      offset: .zero,
      blur: iconSize * 0.4 * parameters.scale,
      color: shadowColor
    )

    context.setFillColor(color.withAlphaComponent(parameters.opacity).cgColor)
    context.fillEllipse(in: rect)

    return image
  }

  private static let defaultIdleColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)
}

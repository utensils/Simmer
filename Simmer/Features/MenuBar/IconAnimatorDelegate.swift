//
//  IconAnimatorDelegate.swift
//  Simmer
//
//  Created on 2025-10-28
//

import AppKit

/// Callback protocol for IconAnimator to notify MenuBarController of animation state changes.
/// Matches contract defined in specs/001-mvp-core/contracts/internal-protocols.md.
protocol IconAnimatorDelegate: AnyObject {
    /// Called when animation starts for the given style and color.
    func animationDidStart(style: AnimationStyle, color: CodableColor)

    /// Called when animation finishes and the icon should return to idle.
    func animationDidEnd()

    /// Called whenever a rendered frame is ready and should be displayed.
    func updateIcon(_ image: NSImage)
}

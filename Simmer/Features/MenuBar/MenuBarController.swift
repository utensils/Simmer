//
//  MenuBarController.swift
//  Simmer
//
//  Created on 2025-10-28
//

import AppKit

/// Manages the NSStatusItem that represents Simmer in the menu bar.
/// Handles icon updates coming from the IconAnimator.
@MainActor
final class MenuBarController: NSObject {
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let iconAnimator: IconAnimator

    init(
        statusBar: NSStatusBar,
        iconAnimator: IconAnimator
    ) {
        self.statusBar = statusBar
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.iconAnimator = iconAnimator
        super.init()

        configureStatusItem()
        self.iconAnimator.delegate = self
    }

    convenience init(statusBar: NSStatusBar = .system) {
        self.init(statusBar: statusBar, iconAnimator: IconAnimator())
    }

    deinit {
        statusBar.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = iconAnimator.idleIcon
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Simmer"
    }
}

// MARK: - IconAnimatorDelegate

extension MenuBarController: IconAnimatorDelegate {
    func animationDidStart(style: AnimationStyle, color: CodableColor) {
        statusItem.button?.appearsDisabled = false
    }

    func animationDidEnd() {
        statusItem.button?.image = iconAnimator.idleIcon
    }

    func updateIcon(_ image: NSImage) {
        statusItem.button?.image = image
    }
}

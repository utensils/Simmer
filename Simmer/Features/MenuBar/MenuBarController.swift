//
//  MenuBarController.swift
//  Simmer
//
//  Manages the NSStatusItem, coordinates icon animation, and builds menu content.
//

import AppKit

/// Manages the Simmer status item, including icon updates
/// and dynamic menu construction.
@MainActor
internal final class MenuBarController: NSObject {
  private let statusBar: NSStatusBar
  private let statusItem: NSStatusItem
  private let iconAnimator: IconAnimator
  private let menuBuilder: MenuBuilder
  private var currentMenu: NSMenu?

  /// Creates a controller that owns the status item, icon animator, and menu builder.
  /// - Parameters:
  ///   - statusBar: Status bar used to create the menu bar item (injected for testing).
  ///   - iconAnimator: Animator responsible for icon rendering and performance fallback.
  ///   - menuBuilder: Factory that generates the dynamic status menu.
  init(
    statusBar: NSStatusBar,
    iconAnimator: IconAnimator,
    menuBuilder: MenuBuilder
  ) {
    self.statusBar = statusBar
    self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
    self.iconAnimator = iconAnimator
    self.menuBuilder = menuBuilder
    super.init()

    configureStatusItem()
    refreshMenu()
    self.iconAnimator.delegate = self
  }

  deinit {
    statusBar.removeStatusItem(statusItem)
  }

  /// Rebuilds the menu from the latest match history.
  func refreshMenu() {
    let menu = menuBuilder.buildMatchHistoryMenu()
    menu.delegate = self
    statusItem.menu = menu
    currentMenu = menu
  }

  /// Called when match history changes so the next click shows fresh content.
  func handleHistoryUpdate() {
    refreshMenu()
  }

  /// Called when warning state changes so the menu reflects new alerts.
  func handleWarningsUpdate() {
    refreshMenu()
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

// MARK: - NSMenuDelegate

extension MenuBarController: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    // Always rebuild right before display so history reflects the latest events.
    refreshMenu()
  }
}

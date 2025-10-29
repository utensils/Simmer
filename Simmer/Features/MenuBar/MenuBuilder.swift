//
//  MenuBuilder.swift
//  Simmer
//
//  Builds the NSMenu content for the Simmer status item, including
//  recent match history and menu actions.
//

import AppKit

/// Produces menu items for the Simmer status item using match history data.
@MainActor
internal final class MenuBuilder: NSObject {
  private let matchEventHandler: MatchEventHandler
  private let dateProvider: () -> Date
  private let historyLimit: Int
  private let settingsHandler: @MainActor () -> Void
  private let quitHandler: @MainActor () -> Void

  init(
    matchEventHandler: MatchEventHandler,
    dateProvider: @escaping () -> Date = Date.init,
    historyLimit: Int = 10,
    settingsHandler: @escaping @MainActor () -> Void = MenuBuilder.defaultSettingsHandler(),
    quitHandler: @escaping @MainActor () -> Void = MenuBuilder.defaultQuitHandler()
  ) {
    self.matchEventHandler = matchEventHandler
    self.dateProvider = dateProvider
    self.historyLimit = historyLimit
    self.settingsHandler = settingsHandler
    self.quitHandler = quitHandler
    super.init()
  }

  /// Constructs a menu showing the most recent match events followed by actions.
  /// - Returns: An `NSMenu` ready to use for the status item's menu.
  func buildMatchHistoryMenu() -> NSMenu {
    let menu = NSMenu()
    let warnings = matchEventHandler.activeWarnings
    if !warnings.isEmpty {
      warnings.forEach { warning in
        menu.addItem(makeWarningItem(for: warning))
      }
      menu.addItem(.separator())
    }

    let events = matchEventHandler.recentMatches(limit: historyLimit)

    if events.isEmpty {
      menu.addItem(makeEmptyStateItem())
    } else {
      events.forEach { event in
        menu.addItem(makeMenuItem(for: event))
      }
    }

    menu.addItem(.separator())
    menu.addItem(makeClearAllItem(isEnabled: !events.isEmpty))
    menu.addItem(makeSettingsItem())
    menu.addItem(makeQuitItem())

    return menu
  }

  // MARK: - Actions

  @objc
  private func clearHistoryAction(_ sender: Any?) {
    matchEventHandler.clearHistory()
  }

  @objc
  private func settingsAction(_ sender: Any?) {
    settingsHandler()
  }

  @objc
  private func quitAction(_ sender: Any?) {
    quitHandler()
  }

  @objc
  private func acknowledgeWarningAction(_ sender: NSMenuItem?) {
    guard let warning = sender?.representedObject as? FrequentMatchWarning else { return }
    matchEventHandler.acknowledgeWarning(for: warning.patternID)
  }

  // MARK: - Menu Item Builders

  private func makeMenuItem(for event: MatchEvent) -> NSMenuItem {
    let now = dateProvider()
    let relativeTime = RelativeTimeFormatter.string(
      from: event.timestamp,
      relativeTo: now
    )
    let excerpt = excerptText(for: event)

    var title = "\(event.patternName) • \(relativeTime)"
    if !excerpt.isEmpty {
      title += " — \(excerpt)"
    }

    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.toolTip = event.matchedLine
    item.representedObject = event
    item.target = nil
    return item
  }

  private func makeEmptyStateItem() -> NSMenuItem {
    let item = NSMenuItem(title: "No recent matches", action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  private func makeClearAllItem(isEnabled: Bool) -> NSMenuItem {
    let item = NSMenuItem(title: "Clear All", action: #selector(clearHistoryAction(_:)), keyEquivalent: "")
    item.target = self
    item.isEnabled = isEnabled
    return item
  }

  private func makeSettingsItem() -> NSMenuItem {
    let item = NSMenuItem(title: "Settings", action: #selector(settingsAction(_:)), keyEquivalent: ",")
    item.target = self
    return item
  }

  private func makeQuitItem() -> NSMenuItem {
    let item = NSMenuItem(title: "Quit Simmer", action: #selector(quitAction(_:)), keyEquivalent: "")
    item.target = self
    return item
  }

  private func makeWarningItem(for warning: FrequentMatchWarning) -> NSMenuItem {
    let item = NSMenuItem(
      title: "⚠️ \(warning.message)",
      action: #selector(acknowledgeWarningAction(_:)),
      keyEquivalent: ""
    )
    item.target = self
    item.representedObject = warning
    item.toolTip = "Dismiss warning"
    item.attributedTitle = NSAttributedString(
      string: item.title,
      attributes: [
        .foregroundColor: NSColor.systemYellow,
        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
      ]
    )
    return item
  }

  private func excerptText(for event: MatchEvent) -> String {
    let sanitized = event.matchedLine
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !sanitized.isEmpty else { return "" }
    let maxLength = 60
    if sanitized.count <= maxLength {
      return sanitized
    }

    let endIndex = sanitized.index(sanitized.startIndex, offsetBy: maxLength)
    return String(sanitized[..<endIndex]) + "..."
  }

  // MARK: - Default Handlers

  nonisolated private static func defaultSettingsHandler() -> @MainActor () -> Void {
    return {
      let alert = NSAlert()
      alert.messageText = "Settings coming soon"
      alert.informativeText = "The settings window will be available in a future update."
      alert.alertStyle = .informational
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }

  nonisolated private static func defaultQuitHandler() -> @MainActor () -> Void {
    return {
      NSApplication.shared.terminate(nil)
    }
  }
}

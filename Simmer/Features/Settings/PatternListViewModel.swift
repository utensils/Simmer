//
//  PatternListViewModel.swift
//  Simmer
//
//  ObservableObject wrapping ConfigurationStore for SwiftUI pattern list.
//

import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

/// View model managing pattern CRUD operations and state for PatternListView.
@MainActor
internal final class PatternListViewModel: ObservableObject {
  private static let maxPatternCount = 20
  private static let patternLimitMessage = "Maximum 20 patterns supported"

  @Published var patterns: [LogPattern] = []
  @Published var errorMessage: String?
  @Published var launchAtLoginEnabled = false
  @Published var isLaunchAtLoginAvailable = false

  private let store: any ConfigurationStoreProtocol
  private let logMonitor: LogMonitoring?
  private let launchAtLoginController: LaunchAtLoginControlling
  private let exporter: ConfigurationExporting
  private let importer: ConfigurationImporting
  private let exportURLProvider: @MainActor () -> URL?
  private let importURLProvider: @MainActor () -> URL?
  private var patternsObserver: NSObjectProtocol?

  nonisolated init(
    store: any ConfigurationStoreProtocol,
    logMonitor: LogMonitoring? = nil,
    launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController(),
    exporter: ConfigurationExporting = ConfigurationExporter(),
    importer: ConfigurationImporting = ConfigurationImporter(),
    exportURLProvider: @escaping @MainActor () -> URL? = { PatternListViewModel.defaultExportURL()() },
    importURLProvider: @escaping @MainActor () -> URL? = { PatternListViewModel.defaultImportURL()() }
  ) {
    self.store = store
    self.logMonitor = logMonitor
    self.launchAtLoginController = launchAtLoginController
    self.exporter = exporter
    self.importer = importer
    self.exportURLProvider = exportURLProvider
    self.importURLProvider = importURLProvider
    patternsObserver = NotificationCenter.default.addObserver(
      forName: .logMonitorPatternsDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.loadPatterns()
    }
    refreshLaunchAtLoginState()
  }

  deinit {
    if let observer = patternsObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  /// Loads all patterns from persistent storage.
  func loadPatterns() {
    patterns = store.loadPatterns()
    refreshLaunchAtLoginState()
  }

  /// Adds a new pattern and persists to storage.
  /// - Parameter pattern: The pattern to add
  func addPattern(_ pattern: LogPattern) {
    guard patterns.count < Self.maxPatternCount else {
      errorMessage = Self.patternLimitMessage
      return
    }

    patterns.append(pattern)
    if savePatterns() {
      logMonitor?.reloadPatterns()
    }
  }

  /// Updates an existing pattern in storage.
  /// - Parameter pattern: The pattern to update
  func updatePattern(_ pattern: LogPattern) {
    guard let index = patterns.firstIndex(where: { $0.id == pattern.id }) else {
      errorMessage = "Pattern not found"
      return
    }
    patterns[index] = pattern
    do {
      try store.updatePattern(pattern)
      logMonitor?.setPatternEnabled(pattern.id, isEnabled: pattern.enabled)
    } catch {
      errorMessage = "Failed to update pattern: \(error.localizedDescription)"
      loadPatterns() // Reload to restore consistent state
    }
  }

  /// Deletes a pattern from storage.
  /// - Parameter id: UUID of the pattern to delete
  func deletePattern(id: UUID) {
    do {
      try store.deletePattern(id: id)
      patterns.removeAll { $0.id == id }
      logMonitor?.setPatternEnabled(id, isEnabled: false)
    } catch {
      errorMessage = "Failed to delete pattern: \(error.localizedDescription)"
    }
  }

  /// Toggles the enabled state of a pattern.
  /// - Parameter id: UUID of the pattern to toggle
  func toggleEnabled(id: UUID) {
    guard let index = patterns.firstIndex(where: { $0.id == id }) else {
      errorMessage = "Pattern not found"
      return
    }
    var pattern = patterns[index]
    pattern.enabled.toggle()
    updatePattern(pattern)
  }

  /// Saves all patterns to a JSON file selected by the user.
  func exportPatterns() {
    guard let url = exportURLProvider() else { return }

    do {
      try exporter.export(patterns: patterns, to: url)
    } catch {
      errorMessage = localizedDescription(for: error) ?? "Failed to export patterns."
    }
  }

  /// Imports patterns from a JSON file selected by the user and merges them with the current list.
  func importPatterns() {
    guard let url = importURLProvider() else { return }

    do {
      let importedPatterns = try importer.importPatterns(from: url)
      try mergeImportedPatterns(importedPatterns)
      logMonitor?.reloadPatterns()
    } catch {
      errorMessage = localizedDescription(for: error) ?? "Failed to import patterns."
    }
  }

  /// Clears any displayed error message.
  func clearError() {
    errorMessage = nil
  }

  /// Updates the Launch at Login preference.
  /// - Parameter enabled: Desired value for launch at login.
  func setLaunchAtLoginEnabled(_ enabled: Bool) {
    guard launchAtLoginController.isAvailable else {
      handleLaunchAtLoginUnavailable()
      return
    }

    let previous = launchAtLoginEnabled
    launchAtLoginEnabled = enabled

    do {
      try launchAtLoginController.setEnabled(enabled)
      updateLaunchAtLoginState()
    } catch {
      handleLaunchAtLoginError(error, previousValue: previous)
    }
  }

  // MARK: - Private Helpers

  @discardableResult
  private func savePatterns() -> Bool {
    do {
      try store.savePatterns(patterns)
      return true
    } catch {
      errorMessage = "Failed to save patterns: \(error.localizedDescription)"
      loadPatterns() // Reload to restore consistent state
      return false
    }
  }

  private func refreshLaunchAtLoginState() {
    launchAtLoginEnabled = launchAtLoginController.resolvedPreference()
    isLaunchAtLoginAvailable = launchAtLoginController.isAvailable
  }

  private func mergeImportedPatterns(_ imported: [LogPattern]) throws {
    var merged = patterns
    for pattern in imported {
      if let index = merged.firstIndex(where: { $0.id == pattern.id }) {
        merged[index] = pattern
      } else {
        merged.append(pattern)
      }
    }

    guard merged.count <= Self.maxPatternCount else {
      throw ConfigurationImportError.validationFailed(messages: [Self.patternLimitMessage])
    }

    do {
      try store.savePatterns(merged)
      patterns = merged
    } catch {
      throw error
    }
  }

  private func localizedDescription(for error: Error) -> String? {
    if let localized = error as? LocalizedError, let message = localized.errorDescription {
      return message
    }
    return (error as NSError).localizedDescription
  }

  private func handleLaunchAtLoginUnavailable() {
    launchAtLoginEnabled = false
    isLaunchAtLoginAvailable = false
    errorMessage = LaunchAtLoginError.notSupported.errorDescription
  }

  private func updateLaunchAtLoginState() {
    launchAtLoginEnabled = launchAtLoginController.resolvedPreference()
    isLaunchAtLoginAvailable = launchAtLoginController.isAvailable
  }

  private func handleLaunchAtLoginError(_ error: Error, previousValue: Bool) {
    launchAtLoginEnabled = previousValue
    if let localized = error as? LocalizedError, let message = localized.errorDescription {
      errorMessage = message
    } else {
      errorMessage = "Failed to update Launch at Login: \(error.localizedDescription)"
    }
  }
}

// MARK: - File Panel Helpers

private extension PatternListViewModel {
  nonisolated static func defaultExportURL() -> @MainActor () -> URL? {
    return {
      let panel = NSSavePanel()
      panel.allowedContentTypes = [UTType.json]
      panel.nameFieldStringValue = "SimmerPatterns.json"
      panel.canCreateDirectories = true
      panel.isExtensionHidden = false
      return panel.runModal() == .OK ? panel.url : nil
    }
  }

  nonisolated static func defaultImportURL() -> @MainActor () -> URL? {
    return {
      let panel = NSOpenPanel()
      panel.allowedContentTypes = [UTType.json]
      panel.canChooseDirectories = false
      panel.canChooseFiles = true
      panel.allowsMultipleSelection = false
      return panel.runModal() == .OK ? panel.url : nil
    }
  }
}

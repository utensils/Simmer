//
//  PatternListViewModel.swift
//  Simmer
//
//  ObservableObject wrapping ConfigurationStore for SwiftUI pattern list.
//

import Foundation
import Combine

/// View model managing pattern CRUD operations and state for PatternListView.
@MainActor
class PatternListViewModel: ObservableObject {
  @Published var patterns: [LogPattern] = []
  @Published var errorMessage: String?
  @Published var launchAtLoginEnabled = false
  @Published var isLaunchAtLoginAvailable = false

  private let store: any ConfigurationStoreProtocol
  private let logMonitor: LogMonitoring?
  private let launchAtLoginController: LaunchAtLoginControlling
  private var patternsObserver: NSObjectProtocol?

  init(
    store: any ConfigurationStoreProtocol,
    logMonitor: LogMonitoring? = nil,
    launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController()
  ) {
    self.store = store
    self.logMonitor = logMonitor
    self.launchAtLoginController = launchAtLoginController
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

  /// Clears any displayed error message.
  func clearError() {
    errorMessage = nil
  }

  /// Updates the Launch at Login preference.
  /// - Parameter enabled: Desired value for launch at login.
  func setLaunchAtLoginEnabled(_ enabled: Bool) {
    guard launchAtLoginController.isAvailable else {
      launchAtLoginEnabled = false
      errorMessage = LaunchAtLoginError.notSupported.errorDescription
      return
    }

    let previous = launchAtLoginEnabled
    do {
      try launchAtLoginController.setEnabled(enabled)
      launchAtLoginEnabled = enabled
    } catch {
      launchAtLoginEnabled = previous
      if let localized = error as? LocalizedError, let message = localized.errorDescription {
        errorMessage = message
      } else {
        errorMessage = "Failed to update Launch at Login: \(error.localizedDescription)"
      }
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
}

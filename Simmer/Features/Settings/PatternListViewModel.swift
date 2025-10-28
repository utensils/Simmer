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

  private let store: any ConfigurationStoreProtocol
  private let logMonitor: LogMonitor?

  init(
    store: any ConfigurationStoreProtocol,
    logMonitor: LogMonitor? = nil
  ) {
    self.store = store
    self.logMonitor = logMonitor
  }

  /// Loads all patterns from persistent storage.
  func loadPatterns() {
    patterns = store.loadPatterns()
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
      logMonitor?.reloadPatterns()
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
      logMonitor?.reloadPatterns()
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
}

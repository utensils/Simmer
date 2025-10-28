//
//  PatternListView.swift
//  Simmer
//
//  SwiftUI List view for pattern CRUD operations with add/edit/delete actions.
//

import SwiftUI

/// Displays user-configured log patterns with add, edit, delete, and toggle actions.
struct PatternListView: View {
  @StateObject private var viewModel: PatternListViewModel
  @State private var showingAddSheet = false
  @State private var editingPattern: LogPattern?

  init(
    store: any ConfigurationStoreProtocol = ConfigurationStore(),
    logMonitor: LogMonitor? = nil
  ) {
    _viewModel = StateObject(
      wrappedValue: PatternListViewModel(
        store: store,
        logMonitor: logMonitor
      )
    )
  }

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.patterns.isEmpty {
          emptyStateView
        } else {
          patternListView
        }
      }
      .onAppear {
        viewModel.loadPatterns()
      }
      .navigationTitle("Log Patterns")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: { showingAddSheet = true }) {
            Label("Add Pattern", systemImage: "plus")
          }
        }
      }
      .sheet(isPresented: $showingAddSheet) {
        PatternEditorView(pattern: nil) { newPattern in
          viewModel.addPattern(newPattern)
        }
      }
      .sheet(item: $editingPattern) { pattern in
        PatternEditorView(pattern: pattern) { updatedPattern in
          viewModel.updatePattern(updatedPattern)
          editingPattern = nil
        }
      }
      .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
        Button("OK") {
          viewModel.clearError()
        }
      } message: { message in
        Text(message)
      }
    }
  }

  // MARK: - Subviews

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      Text("No Patterns Configured")
        .font(.headline)
      Text("Click + to add your first log monitoring pattern")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var patternListView: some View {
    List {
      ForEach(viewModel.patterns) { pattern in
        PatternRow(pattern: pattern) {
          editingPattern = pattern
        } onToggle: {
          viewModel.toggleEnabled(id: pattern.id)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            viewModel.deletePattern(id: pattern.id)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
  }

}

// MARK: - PatternRow

/// Individual row view for a single pattern in the list.
private struct PatternRow: View {
  let pattern: LogPattern
  let onEdit: () -> Void
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Color indicator
      Circle()
        .fill(Color(
          red: pattern.color.red,
          green: pattern.color.green,
          blue: pattern.color.blue
        ))
        .frame(width: 16, height: 16)

      VStack(alignment: .leading, spacing: 4) {
        Text(pattern.name)
          .font(.headline)
          .foregroundColor(pattern.enabled ? .primary : .secondary)

        HStack(spacing: 8) {
          Text(pattern.animationStyle.rawValue.capitalized)
            .font(.caption)
            .foregroundColor(.secondary)
          Text("•")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(pattern.logPath)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      Toggle("", isOn: Binding(
        get: { pattern.enabled },
        set: { _ in onToggle() }
      ))
      .labelsHidden()
    }
    .contentShape(Rectangle())
    .onTapGesture {
      onEdit()
    }
  }
}

// MARK: - Previews

  #Preview("Empty State") {
    PatternListView(store: PreviewConfigurationStore(), logMonitor: nil)
  }

  #Preview("With Patterns") {
    PatternListView(store: PreviewConfigurationStore(), logMonitor: nil)
  }

/// Mock store for previews with sample data.
private struct PreviewConfigurationStore: ConfigurationStoreProtocol {
  func loadPatterns() -> [LogPattern] {
    [
      LogPattern(
        name: "Error Detector",
        regex: "ERROR|FATAL",
        logPath: "/var/log/app.log",
        color: CodableColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
        animationStyle: .pulse,
        enabled: true
      ),
      LogPattern(
        name: "Queue Failures",
        regex: "queue.*failed",
        logPath: "~/logs/worker.log",
        color: CodableColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
        animationStyle: .glow,
        enabled: false
      )
    ]
  }

  func savePatterns(_ patterns: [LogPattern]) throws {}
  func deletePattern(id: UUID) throws {}
  func updatePattern(_ pattern: LogPattern) throws {}
}

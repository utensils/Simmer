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
    logMonitor: LogMonitoring? = nil,
    launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController()
  ) {
    _viewModel = StateObject(
      wrappedValue: PatternListViewModel(
        store: store,
        logMonitor: logMonitor,
        launchAtLoginController: launchAtLoginController
      )
    )
  }

  var body: some View {
    NavigationStack {
      patternListView
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

  private var patternListView: some View {
    List {
      generalSettingsSection
      patternsSection
    }
  }

  private var generalSettingsSection: some View {
    Section("General") {
      Toggle(
        "Launch at Login",
        isOn: Binding(
          get: { viewModel.launchAtLoginEnabled },
          set: { viewModel.setLaunchAtLoginEnabled($0) }
        )
      )
      .toggleStyle(.switch)
      .disabled(!viewModel.isLaunchAtLoginAvailable)

      if !viewModel.isLaunchAtLoginAvailable {
        Text("Requires macOS 13 or newer.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var patternsSection: some View {
    Section("Log Patterns") {
      if viewModel.patterns.isEmpty {
        emptyStateRow
      } else {
        ForEach(viewModel.patterns) { pattern in
          PatternRow(
            pattern: pattern,
            onEdit: {
              editingPattern = pattern
            },
            onToggle: {
              viewModel.toggleEnabled(id: pattern.id)
            },
            onDelete: {
              viewModel.deletePattern(id: pattern.id)
            }
          )
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

  private var emptyStateRow: some View {
    VStack(spacing: 10) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)
      Text("No Patterns Configured")
        .font(.headline)
      Text("Click + to add your first log monitoring pattern.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.vertical, 32)
    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
    .listRowSeparator(.hidden)
  }
}

// MARK: - PatternRow

/// Individual row view for a single pattern in the list.
private struct PatternRow: View {
  let pattern: LogPattern
  let onEdit: () -> Void
  let onToggle: () -> Void
  let onDelete: () -> Void

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
      .toggleStyle(.switch)

      Button(role: .destructive) {
        onDelete()
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Delete pattern")
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

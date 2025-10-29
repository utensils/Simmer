//
//  PatternEditorView.swift
//  Simmer
//
//  SwiftUI form for creating and editing log monitoring patterns.
//

import AppKit
import SwiftUI

/// Editor view that captures all fields required for a `LogPattern`.
struct PatternEditorView: View {
  @Environment(\.dismiss) private var dismiss

  private let mode: Mode
  private let onSave: (LogPattern) -> Void
  private let existingPatternID: UUID?

  @State private var name: String
  @State private var regex: String
  @State private var logPath: String
  @State private var color: CodableColor
  @State private var animationStyle: AnimationStyle
  @State private var enabled: Bool

  @State private var regexError: String?
  @State private var errorMessage: String?
  @State private var isShowingErrorAlert = false
  @FocusState private var focusedField: Field?

  @State private var selectedBookmark: FileBookmark?

  private let validator = PatternValidator.self
  private let fileAccessManager = FileAccessManager()

  init(
    pattern: LogPattern?,
    onSave: @escaping (LogPattern) -> Void
  ) {
    self.onSave = onSave

    if let pattern {
      self.mode = .edit
      self.existingPatternID = pattern.id
      _name = State(initialValue: pattern.name)
      _regex = State(initialValue: pattern.regex)
      _logPath = State(initialValue: pattern.logPath)
      _color = State(initialValue: pattern.color)
      _animationStyle = State(initialValue: pattern.animationStyle)
      _enabled = State(initialValue: pattern.enabled)
      _selectedBookmark = State(initialValue: pattern.bookmark)
    } else {
      self.mode = .create
      self.existingPatternID = nil
      _name = State(initialValue: "")
      _regex = State(initialValue: "")
      _logPath = State(initialValue: "")
      _color = State(initialValue: CodableColor(red: 0.2, green: 0.6, blue: 1.0))
      _animationStyle = State(initialValue: .glow)
      _enabled = State(initialValue: true)
      _selectedBookmark = State(initialValue: nil)
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        detailsSection
        logConfigurationSection
        appearanceSection
        statusSection
      }
      .navigationTitle(mode.navigationTitle)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            handleSave()
          }
          .disabled(!canSave)
        }
      }
      .alert("Error", isPresented: $isShowingErrorAlert, actions: {
        Button("OK", role: .cancel) { errorMessage = nil }
      }, message: {
        if let errorMessage {
          Text(errorMessage)
        }
      })
      .onChange(of: regex) { _, _ in
        regexError = nil
      }
      .onChange(of: focusedField) { _, newValue in
        if newValue != .regex {
          validateRegex()
        }
      }
    }
  }

  // MARK: - Sections

  private var detailsSection: some View {
    Section("Details") {
      TextField("Name", text: $name)
        .textFieldStyle(.roundedBorder)
        .disableAutocorrection(true)

      VStack(alignment: .leading, spacing: 4) {
        TextField("Regular Expression", text: $regex, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .focused($focusedField, equals: .regex)
          .onSubmit { validateRegex() }
        if let regexError {
          Text(regexError)
            .font(.footnote)
            .foregroundStyle(Color.red)
        }
      }
    }
  }

  private var logConfigurationSection: some View {
    Section("Log File") {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
          TextField("Path", text: $logPath)
            .textFieldStyle(.roundedBorder)
            .fontDesign(.monospaced)

          Button {
            openFilePicker()
          } label: {
            Label("Choose…", systemImage: "folder")
              .labelStyle(.iconOnly)
          }
          .help("Select a log file")
        }

        if let bookmark = selectedBookmark {
          Text("Access granted for \(bookmark.filePath)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var appearanceSection: some View {
    Section("Appearance") {
      ColorPickerView(color: $color)

      Picker("Animation Style", selection: $animationStyle) {
        ForEach(AnimationStyle.allCases, id: \.self) { style in
          Text(style.displayName)
            .tag(style)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  private var statusSection: some View {
    Section {
      Toggle("Enabled", isOn: $enabled)
    }
  }

  // MARK: - Actions

  private func handleSave() {
    guard validateRegex() else { return }

    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPath = logPath.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty, !trimmedPath.isEmpty else {
      errorMessage = "Name and log path are required."
      isShowingErrorAlert = true
      return
    }

    let expandedPath = PathExpander.expand(trimmedPath)

    if selectedBookmark == nil {
      do {
        try validateManualPath(expandedPath)
      } catch {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isShowingErrorAlert = true
        return
      }
    }

    let updatedPattern = LogPattern(
      id: existingPatternID ?? UUID(),
      name: trimmedName,
      regex: regex,
      logPath: expandedPath,
      color: color,
      animationStyle: animationStyle,
      enabled: enabled,
      bookmark: selectedBookmark
    )

    onSave(updatedPattern)
    dismiss()
  }

  private func openFilePicker() {
    do {
      let bookmark = try fileAccessManager.requestAccess()
      selectedBookmark = bookmark
      logPath = bookmark.filePath
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      isShowingErrorAlert = true
    }
  }

  @discardableResult
  private func validateRegex() -> Bool {
    let result = validator.validate(regex)
    regexError = result.errorMessage
    return result.isValid
  }

  // MARK: - Computed Properties

  private var canSave: Bool {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPath = logPath.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmedName.isEmpty &&
      !trimmedPath.isEmpty &&
      validator.isValid(regex)
  }
}

// MARK: - Supporting Types

extension PatternEditorView {
  private enum Mode {
    case create
    case edit

    var navigationTitle: String {
      switch self {
      case .create:
        return "New Pattern"
      case .edit:
        return "Edit Pattern"
      }
    }
  }

  private enum Field: Hashable {
    case regex
  }
}

private extension AnimationStyle {
  var displayName: String {
    switch self {
    case .glow:
      return "Glow"
    case .pulse:
      return "Pulse"
    case .blink:
      return "Blink"
    }
  }
}

// MARK: - Manual Path Validation

private enum ManualPathValidationError: LocalizedError {
  case missing(path: String)
  case directory(path: String)
  case unreadable(path: String)

  var errorDescription: String? {
    switch self {
    case .missing(let path):
      return """
      “\(path)” does not exist. Use the Choose… button to select an existing log file.
      """
    case .directory(let path):
      return """
      “\(path)” is a directory. Select a specific log file instead.
      """
    case .unreadable(let path):
      return """
      Simmer does not have permission to read “\(path)”. Use the Choose… button so macOS can grant access.
      """
    }
  }
}

private func validateManualPath(_ path: String) throws {
  let fileManager = FileManager.default
  var isDirectory: ObjCBool = false

  guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
    throw ManualPathValidationError.missing(path: path)
  }

  if isDirectory.boolValue {
    throw ManualPathValidationError.directory(path: path)
  }

  guard fileManager.isReadableFile(atPath: path) else {
    throw ManualPathValidationError.unreadable(path: path)
  }

  let url = URL(fileURLWithPath: path)
  do {
    let handle = try FileHandle(forReadingFrom: url)
    if #available(macOS 13, *) {
      try handle.close()
    } else {
      handle.closeFile()
    }
  } catch {
    throw ManualPathValidationError.unreadable(path: path)
  }
}

#if DEBUG
struct PatternEditorView_Previews: PreviewProvider {
  static var previews: some View {
    PatternEditorView(pattern: nil, onSave: { _ in })
      .frame(width: 420, height: 520)
  }
}
#endif

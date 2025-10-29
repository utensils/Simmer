//
//  ColorPickerView.swift
//  Simmer
//
//  SwiftUI component for adjusting CodableColor values with a native picker and RGB sliders.
//

import AppKit
import SwiftUI

/// Wraps SwiftUI's ColorPicker with RGB sliders to edit a `CodableColor`.
internal struct ColorPickerView: View {
  @Binding var color: CodableColor

  private var currentColor: Color {
    Color(
      red: color.red,
      green: color.green,
      blue: color.blue,
      opacity: color.alpha
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ColorPicker("Animation Color", selection: bindingForColorPicker, supportsOpacity: false)

      previewSwatch

      componentSlider(title: "Red", value: sliderBinding(for: .red), tint: .red)
      componentSlider(title: "Green", value: sliderBinding(for: .green), tint: .green)
      componentSlider(title: "Blue", value: sliderBinding(for: .blue), tint: .blue)
    }
    .padding(.vertical, 4)
    .onDisappear {
      Self.closeActiveColorPanel()
    }
  }

  // MARK: - Subviews

  private var previewSwatch: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(currentColor)
      .frame(height: 32)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      )
  }

  private func componentSlider(
    title: String,
    value: Binding<Double>,
    tint: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
        Spacer()
        Text("\(Int(value.wrappedValue))")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Slider(value: value, in: 0...255, step: 1)
        .tint(tint)
    }
  }

  // MARK: - Bindings

  internal var bindingForColorPicker: Binding<Color> {
    Binding<Color>(
      get: { currentColor },
      set: { newValue in
        updateColor(with: newValue)
      }
    )
  }

  internal func sliderBinding(for component: RGBComponent) -> Binding<Double> {
    Binding<Double>(
      get: {
        switch component {
        case .red:
          return color.red * 255

        case .green:
          return color.green * 255

        case .blue:
          return color.blue * 255
        }
      },
      set: { newValue in
        var red = color.red
        var green = color.green
        var blue = color.blue

        let normalized = newValue / 255

        switch component {
        case .red:
          red = normalized

        case .green:
          green = normalized

        case .blue:
          blue = normalized
        }

        color = CodableColor(
          red: red,
          green: green,
          blue: blue,
          alpha: color.alpha
        )
      }
    )
  }

  internal func updateColor(with color: Color) {
#if os(macOS)
    if let cgColor = color.cgColor, let nsColor = NSColor(cgColor: cgColor) {
      self.color = CodableColor(nsColor: nsColor)
      return
    }
    #endif

    guard let cgColor = color.cgColor, let components = cgColor.components, components.count >= 3 else {
      return
    }

    self.color = CodableColor(
      red: Double(components[0]),
      green: Double(components[1]),
      blue: Double(components[2]),
      alpha: Double(cgColor.alpha)
    )
  }

  internal enum RGBComponent {
    case red
    case green
    case blue
  }

  // MARK: - Color panel integration

  internal static var isColorPanelVisible: () -> Bool = {
#if os(macOS)
    NSColorPanel.shared.isVisible
#else
    false
#endif
  }

  internal static var dismissColorPanel: () -> Void = {
#if os(macOS)
    NSColorPanel.shared.orderOut(nil)
#else
    return
#endif
  }

  internal static func closeActiveColorPanel() {
#if os(macOS)
    if isColorPanelVisible() {
      dismissColorPanel()
    }
#endif
  }

  internal static func resetColorPanelHooks() {
#if os(macOS)
    isColorPanelVisible = { NSColorPanel.shared.isVisible }
    dismissColorPanel = { NSColorPanel.shared.orderOut(nil) }
#endif
  }
}

// MARK: - Preview

#if DEBUG
internal struct ColorPickerView_Previews: PreviewProvider {
  internal struct PreviewWrapper: View {
    @State private var color = CodableColor(red: 0.4, green: 0.6, blue: 0.9)

    var body: some View {
      ColorPickerView(color: $color)
        .frame(width: 320)
        .padding()
    }
  }

  internal static var previews: some View {
    PreviewWrapper()
      .previewLayout(.sizeThatFits)
  }
}
#endif

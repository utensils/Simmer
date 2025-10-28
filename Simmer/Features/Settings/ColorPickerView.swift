//
//  ColorPickerView.swift
//  Simmer
//
//  SwiftUI color picker with RGB sliders for pattern animation colors.
//

import SwiftUI

/// Provides color selection UI with RGB sliders and color picker for pattern configuration.
struct ColorPickerView: View {
  @Binding var codableColor: CodableColor

  // Local state for slider manipulation (0-255 range for user-friendly display)
  @State private var redValue: Double
  @State private var greenValue: Double
  @State private var blueValue: Double

  init(color: Binding<CodableColor>) {
    self._codableColor = color
    // Initialize slider state from binding
    _redValue = State(initialValue: color.wrappedValue.red * 255.0)
    _greenValue = State(initialValue: color.wrappedValue.green * 255.0)
    _blueValue = State(initialValue: color.wrappedValue.blue * 255.0)
  }

  var body: some View {
    VStack(spacing: 16) {
      // Color preview and system color picker
      HStack {
        // Preview circle
        Circle()
          .fill(codableColor.toColor())
          .frame(width: 50, height: 50)
          .overlay(
            Circle()
              .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
          )

        // System color picker
        ColorPicker("Pick Color", selection: colorBinding)
          .labelsHidden()
          .onChange(of: colorBinding.wrappedValue) { _, newColor in
            updateFromSwiftUIColor(newColor)
          }

        Spacer()
      }

      // RGB Sliders
      VStack(spacing: 12) {
        ColorSlider(
          label: "Red",
          value: $redValue,
          color: .red,
          onChange: updateColorFromSliders
        )

        ColorSlider(
          label: "Green",
          value: $greenValue,
          color: .green,
          onChange: updateColorFromSliders
        )

        ColorSlider(
          label: "Blue",
          value: $blueValue,
          color: .blue,
          onChange: updateColorFromSliders
        )
      }

      // Hex display (read-only)
      HStack {
        Text("Hex:")
          .font(.caption)
          .foregroundColor(.secondary)
        Text(hexString)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
        Spacer()
      }
    }
    .padding()
  }

  // MARK: - Computed Properties

  private var colorBinding: Binding<Color> {
    Binding(
      get: { codableColor.toColor() },
      set: { _ in } // Handled by onChange
    )
  }

  private var hexString: String {
    let r = Int(redValue)
    let g = Int(greenValue)
    let b = Int(blueValue)
    return String(format: "#%02X%02X%02X", r, g, b)
  }

  // MARK: - Color Updates

  private func updateColorFromSliders() {
    codableColor = CodableColor(
      red: redValue / 255.0,
      green: greenValue / 255.0,
      blue: blueValue / 255.0,
      alpha: 1.0
    )
  }

  private func updateFromSwiftUIColor(_ color: Color) {
    // Extract RGB from SwiftUI Color
    #if os(macOS)
    if let nsColor = NSColor(color).usingColorSpace(.deviceRGB) {
      redValue = nsColor.redComponent * 255.0
      greenValue = nsColor.greenComponent * 255.0
      blueValue = nsColor.blueComponent * 255.0
      updateColorFromSliders()
    }
    #endif
  }
}

// MARK: - ColorSlider

/// Individual RGB slider component with label and value display.
private struct ColorSlider: View {
  let label: String
  @Binding var value: Double
  let color: Color
  let onChange: () -> Void

  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
        .frame(width: 40, alignment: .leading)

      Slider(value: $value, in: 0...255, step: 1)
        .tint(color)
        .onChange(of: value) { _, _ in
          onChange()
        }

      Text(String(format: "%.0f", value))
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.secondary)
        .frame(width: 30, alignment: .trailing)
    }
  }
}

// MARK: - Previews

#Preview("Color Picker - Red") {
  @Previewable @State var color = CodableColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
  return ColorPickerView(color: $color)
    .frame(width: 300)
}

#Preview("Color Picker - Custom") {
  @Previewable @State var color = CodableColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
  return ColorPickerView(color: $color)
    .frame(width: 300)
}

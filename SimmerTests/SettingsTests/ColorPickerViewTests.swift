//
//  ColorPickerViewTests.swift
//  SimmerTests
//

import SwiftUI
import XCTest
@testable import Simmer

final class ColorPickerViewTests: XCTestCase {
  override func tearDown() {
    ColorPickerView.resetColorPanelHooks()
    super.tearDown()
  }

  func testSliderBindingUpdatesColorComponent() {
    var color = CodableColor(red: 0.2, green: 0.3, blue: 0.4)
    let binding = Binding(
      get: { color },
      set: { color = $0 }
    )

    let view = ColorPickerView(color: binding)
    let redSlider = view.sliderBinding(for: .red)

    redSlider.wrappedValue = 128

    XCTAssertEqual(color.red, 128.0 / 255.0, accuracy: 0.0001)
  }

  func testColorPickerBindingAppliesSwiftUIColor() {
    var color = CodableColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    let binding = Binding(
      get: { color },
      set: { color = $0 }
    )

    var view = ColorPickerView(color: binding)
    let newColor = Color(red: 0.4, green: 0.5, blue: 0.6)

    view.updateColor(with: newColor)

    XCTAssertEqual(color.red, 0.4, accuracy: 0.0001)
    XCTAssertEqual(color.green, 0.5, accuracy: 0.0001)
    XCTAssertEqual(color.blue, 0.6, accuracy: 0.0001)
  }

  func testCloseActiveColorPanelWhenVisibleOrdersOutPanel() {
    var dismissCalled = false
    ColorPickerView.isColorPanelVisible = { true }
    ColorPickerView.dismissColorPanel = { dismissCalled = true }

    ColorPickerView.closeActiveColorPanel()

    XCTAssertTrue(dismissCalled)
  }

  func testCloseActiveColorPanelWhenHiddenDoesNotOrderOut() {
    var dismissCalled = false
    ColorPickerView.isColorPanelVisible = { false }
    ColorPickerView.dismissColorPanel = { dismissCalled = true }

    ColorPickerView.closeActiveColorPanel()

    XCTAssertFalse(dismissCalled)
  }
}

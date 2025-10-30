//
//  IconAnimationUtilitiesTests.swift
//  SimmerTests
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
internal final class IconAnimationUtilitiesTests: XCTestCase {
  func testFrameCalculatorProducesVisibleBlinkFrameAtZero() {
    let calculator = IconAnimationFrameCalculator()

    let parameters = calculator.parameters(for: .blink, elapsed: 0)

    XCTAssertTrue(parameters.visible)
    XCTAssertEqual(parameters.opacity, 1.0, accuracy: 0.0001)
  }

  func testFrameCalculatorProducesHiddenBlinkFrameAfterHalfSecond() {
    let calculator = IconAnimationFrameCalculator()

    let parameters = calculator.parameters(for: .blink, elapsed: 0.5)

    XCTAssertFalse(parameters.visible)
    XCTAssertEqual(parameters.opacity, 0.0, accuracy: 0.0001)
  }

  func testRendererProducesImageMatchingConfiguredSize() {
    let renderer = IconAnimationRenderer(iconSize: 22)

    let image = renderer.renderIcon(
      color: NSColor.systemBlue,
      parameters: IconAnimationFrameParameters(scale: 1.0, opacity: 1.0, visible: true)
    )

    XCTAssertEqual(image.size.width, 22, accuracy: 0.0001)
    XCTAssertEqual(image.size.height, 22, accuracy: 0.0001)
  }
}

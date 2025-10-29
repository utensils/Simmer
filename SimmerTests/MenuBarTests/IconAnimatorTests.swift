//
//  IconAnimatorTests.swift
//  SimmerTests
//

import XCTest
@testable import Simmer

@MainActor
internal final class IconAnimatorTests: XCTestCase {
  private var timer: TestAnimationTimer!
  private var clock: TestAnimationClock!
  private var animator: IconAnimator!
  private var delegate: TestIconAnimatorDelegate!

  override func setUp() {
    super.setUp()
    timer = TestAnimationTimer()
    clock = TestAnimationClock()
    delegate = TestIconAnimatorDelegate()
    animator = makeAnimator()
  }

  override func tearDown() {
    animator.stopAnimation()
    animator = nil
    delegate = nil
    timer = nil
    clock = nil
    super.tearDown()
  }

  func test_startAnimation_notifiesDelegateAndGeneratesFrame() {
    start(style: .glow)

    XCTAssertEqual(delegate.started.count, 1)
    XCTAssertEqual(delegate.started.first?.0, .glow)
    XCTAssertEqual(timer.interval ?? 0, 1.0 / 60.0, accuracy: 0.0001)

    timer.fire()
    XCTAssertNotNil(delegate.images.last)
    XCTAssertEqual(animator.state, .animating(style: .glow, color: color()))
    XCTAssertNotNil(animator.debugLastParameters)
  }

  func test_glowAnimation_interpolatesOpacityOverCycle() {
    start(style: .glow)

    timer.fire()
    let startOpacity = animator.debugLastParameters?.opacity ?? 0

    clock.advance(by: 1.0) // Halfway through 2s cycle
    timer.fire()
    let midOpacity = animator.debugLastParameters?.opacity ?? 0
    XCTAssertGreaterThan(midOpacity, startOpacity)

    clock.advance(by: 1.0)
    timer.fire()
    let endOpacity = animator.debugLastParameters?.opacity ?? 0
    XCTAssertLessThan(endOpacity, midOpacity)
  }

  func test_pulseAnimation_scalesIcon() {
    start(style: .pulse)

    timer.fire()
    let baseScale = animator.debugLastParameters?.scale ?? 0

    clock.advance(by: 0.75)
    timer.fire()
    let peakScale = animator.debugLastParameters?.scale ?? 0

    XCTAssertGreaterThan(peakScale, baseScale)
  }

  func test_blinkAnimation_togglesVisibilityEveryHalfSecond() {
    start(style: .blink)

    timer.fire()
    let firstVisible = animator.debugLastParameters?.visible
    XCTAssertEqual(firstVisible, true)

    clock.advance(by: 0.5)
    timer.fire()
    let secondVisible = animator.debugLastParameters?.visible
    XCTAssertEqual(secondVisible, false)

    clock.advance(by: 0.5)
    timer.fire()
    let thirdVisible = animator.debugLastParameters?.visible
    XCTAssertEqual(thirdVisible, true)
  }

  func test_stopAnimation_transitionsToIdleAndEnds() {
    start(style: .pulse)
    timer.fire()
    animator.stopAnimation()

    XCTAssertEqual(animator.state, .idle)
    XCTAssertEqual(delegate.endedCount, 1)
    XCTAssertFalse(timer.isRunning)
  }

  func test_frameBudgetExceededSetsDebugFlag() {
    var warningCount = 0
    let frameBudget: TimeInterval = 0.000001

    let first = AnimationFrameBudgetEvaluator.evaluate(
      duration: 0.003,
      frameBudget: frameBudget,
      lastWarning: 0,
      timestamp: 10.0,
      handler: { _ in warningCount += 1 }
    )

    XCTAssertTrue(first.exceeded)
    XCTAssertEqual(warningCount, 1)

    let second = AnimationFrameBudgetEvaluator.evaluate(
      duration: 0.0000005,
      frameBudget: frameBudget,
      lastWarning: first.lastWarning,
      timestamp: 10.5,
      handler: { _ in warningCount += 1 }
    )

    XCTAssertFalse(second.exceeded)
    XCTAssertEqual(warningCount, 1, "Warnings should not repeat when duration stays under budget")

    let third = AnimationFrameBudgetEvaluator.evaluate(
      duration: 0.002,
      frameBudget: frameBudget,
      lastWarning: first.lastWarning,
      timestamp: 11.6,
      handler: { _ in warningCount += 1 }
    )

    XCTAssertTrue(third.exceeded)
    XCTAssertEqual(warningCount, 2)
  }

  func test_budgetViolationsReduceFrameRate() {
    animator = makeAnimator(fallbackViolationThreshold: 2, recoveryFrameThreshold: 3)
    start(style: .glow)
    XCTAssertEqual(animator.debugPerformanceStateDescription, "normal")
    XCTAssertEqual(animator.debugCurrentFrameInterval, 1.0 / 60.0, accuracy: 0.0001)

    // Simulate 2 budget violations (duration exceeds budget)
    animator.simulateRenderDurationForTesting(0.01, timestamp: 0.0)
    animator.simulateRenderDurationForTesting(0.01, timestamp: 0.1)

    XCTAssertEqual(animator.debugPerformanceStateDescription, "reduced",
                   "Should switch to reduced mode after \(2) budget violations")
    XCTAssertEqual(animator.debugCurrentFrameInterval, 1.0 / 30.0, accuracy: 0.0001)
    XCTAssertTrue(timer.isRunning)
  }

  func test_recoveryRestoresNormalFrameRate() {
    animator = makeAnimator(fallbackViolationThreshold: 2, recoveryFrameThreshold: 2)
    start(style: .glow)

    // Simulate 2 budget violations to enter reduced mode
    animator.simulateRenderDurationForTesting(0.01, timestamp: 0.0)
    animator.simulateRenderDurationForTesting(0.01, timestamp: 0.1)
    XCTAssertEqual(animator.debugPerformanceStateDescription, "reduced")

    // Simulate 2 healthy frames to recover to normal mode
    animator.simulateRenderDurationForTesting(0.0001, timestamp: 0.2)
    animator.simulateRenderDurationForTesting(0.0001, timestamp: 0.3)

    XCTAssertEqual(animator.debugPerformanceStateDescription, "normal")
    XCTAssertEqual(animator.debugCurrentFrameInterval, 1.0 / 60.0, accuracy: 0.0001)
    XCTAssertTrue(timer.isRunning)
  }

  // MARK: - Helpers

  private func start(style: AnimationStyle) {
    animator.delegate = delegate
    animator.startAnimation(style: style, color: color())
  }

  private func color() -> CodableColor {
    CodableColor(red: 0.9, green: 0.2, blue: 0.2)
  }

  private func makeAnimator(
    frameBudget: TimeInterval = 0.002,
    fallbackViolationThreshold: Int = 5,
    recoveryFrameThreshold: Int = 30
  ) -> IconAnimator {
    let animator = IconAnimator(
      timerFactory: { [unowned timer] in timer },
      clock: clock,
      frameBudget: frameBudget,
      budgetExceededHandler: nil,
      fallbackViolationThreshold: fallbackViolationThreshold,
      recoveryFrameThreshold: recoveryFrameThreshold
    )
    animator.delegate = delegate
    return animator
  }
}

@MainActor
private final class TestAnimationTimer: AnimationTimer {
  private(set) var interval: TimeInterval?
  private(set) var handler: (() -> Void)?
  private(set) var isRunning = false
  var onStart: (() -> Void)?
  private(set) var startCount = 0

  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
    self.interval = interval
    self.handler = handler
    isRunning = true
    startCount += 1
    onStart?()
  }

  func stop() {
    isRunning = false
    handler = nil
  }

  func fire() {
    handler?()
  }
}

@MainActor
private final class TestAnimationClock: IconAnimatorClock {
  private var current: TimeInterval = 0

  func now() -> TimeInterval {
    current
  }

  func advance(by delta: TimeInterval) {
    current += delta
  }
}

@MainActor
private final class TestIconAnimatorDelegate: IconAnimatorDelegate {
  private(set) var started: [(AnimationStyle, CodableColor)] = []
  private(set) var endedCount = 0
  private(set) var images: [NSImage] = []

  func animationDidStart(style: AnimationStyle, color: CodableColor) {
    started.append((style, color))
  }

  func animationDidEnd() {
    endedCount += 1
  }

  func updateIcon(_ image: NSImage) {
    images.append(image)
  }
}

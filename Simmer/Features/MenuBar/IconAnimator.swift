//
//  IconAnimator.swift
//  Simmer
//
//  Generates Core Graphics frames for status bar icon animations.
//

import AppKit
import QuartzCore
import os

@MainActor
internal protocol IconAnimatorClock {
  func now() -> TimeInterval
}

@MainActor
internal protocol AnimationTimer: AnyObject {
  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
  func stop()
}

@MainActor
internal final class TimerAnimationTimer: AnimationTimer {
  private var timer: Timer?

  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
    stop()
    let scheduled = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      Task { await MainActor.run { handler() } }
    }
    RunLoop.main.add(scheduled, forMode: .common)
    timer = scheduled
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }
}

internal struct SystemAnimationClock: IconAnimatorClock {
  func now() -> TimeInterval {
    CACurrentMediaTime()
  }
}

/// Tracks animation performance and decides when to reduce or restore frame rate.
internal struct IconAnimationPerformanceGovernor {
  internal enum State {
    case normal
    case reduced
  }

  private let fallbackViolationThreshold: Int
  private let recoveryFrameThreshold: Int
  private(set) var state: State = .normal
  private var consecutiveBudgetViolations = 0
  private var consecutiveHealthyFrames = 0

  internal init(fallbackViolationThreshold: Int, recoveryFrameThreshold: Int) {
    self.fallbackViolationThreshold = max(1, fallbackViolationThreshold)
    self.recoveryFrameThreshold = max(1, recoveryFrameThreshold)
  }

  internal mutating func reset() {
    state = .normal
    consecutiveBudgetViolations = 0
    consecutiveHealthyFrames = 0
  }

  internal mutating func recordFrame(exceededBudget: Bool) -> State? {
    if exceededBudget {
      consecutiveBudgetViolations += 1
      consecutiveHealthyFrames = 0
      switch state {
      case .normal where consecutiveBudgetViolations >= fallbackViolationThreshold:
        state = .reduced
        consecutiveBudgetViolations = 0
        return state
      case .reduced:
        return nil
      default:
        return nil
      }
    } else {
      consecutiveBudgetViolations = 0
      switch state {
      case .normal:
        consecutiveHealthyFrames = min(consecutiveHealthyFrames + 1, recoveryFrameThreshold)
        return nil
      case .reduced:
        consecutiveHealthyFrames += 1
        if consecutiveHealthyFrames >= recoveryFrameThreshold {
          state = .normal
          consecutiveHealthyFrames = 0
          return state
        }
        return nil
      }
    }
}
}

@MainActor
internal final class IconAnimator {
  weak var delegate: IconAnimatorDelegate?

  private(set) var state: IconAnimationState = .idle

  private let normalFrameInterval: TimeInterval = 1.0 / 60.0
  private let reducedFrameInterval: TimeInterval
  private let timerFactory: @MainActor () -> AnimationTimer
  private let clock: IconAnimatorClock
  private var timer: AnimationTimer?
  private var animationStart: TimeInterval = 0
  private let logger = Logger(subsystem: "io.utensils.Simmer", category: "IconAnimator")
  private let frameBudget: TimeInterval
  private var lastBudgetWarning: TimeInterval = 0
  private let budgetExceededHandler: (TimeInterval) -> Void
  private var performanceGovernor: IconAnimationPerformanceGovernor
  private let frameCalculator: IconAnimationFrameCalculator
  private let renderer: IconAnimationRenderer

  /// The idle icon image displayed when no animation is active.
  let idleIcon: NSImage

  // Exposed for tests to assert frame progression.
  internal private(set) var debugLastParameters: IconAnimationFrameParameters?
  internal private(set) var debugLastRenderDuration: TimeInterval?
  internal private(set) var debugRenderBudgetExceeded = false
  internal var debugPerformanceStateDescription: String {
    switch performanceGovernor.state {
    case .normal:
      return "normal"

    case .reduced:
      return "reduced"
    }
  }
  internal var debugCurrentFrameInterval: TimeInterval {
    currentFrameInterval
  }
  init(
    iconSize: CGFloat = 18,
    timerFactory: (@MainActor () -> AnimationTimer)? = nil,
    clock: IconAnimatorClock? = nil,
    frameBudget: TimeInterval = 0.002,
    budgetExceededHandler: ((TimeInterval) -> Void)? = nil,
    fallbackViolationThreshold: Int = 5,
    recoveryFrameThreshold: Int = 30,
    reducedFrameInterval: TimeInterval = 1.0 / 30.0
  ) {
    self.timerFactory = timerFactory ?? { TimerAnimationTimer() }
    self.clock = clock ?? SystemAnimationClock()
    self.frameBudget = frameBudget
    if let budgetExceededHandler {
      self.budgetExceededHandler = budgetExceededHandler
    } else {
      self.budgetExceededHandler = { [logger] duration in
        let durationMs = duration * 1_000
        logger.warning(
          "Icon frame rendering exceeded budget: \(durationMs, format: .fixed(precision: 3)) ms"
        )
      }
    }
    performanceGovernor = IconAnimationPerformanceGovernor(
      fallbackViolationThreshold: fallbackViolationThreshold,
      recoveryFrameThreshold: recoveryFrameThreshold
    )
    self.reducedFrameInterval = reducedFrameInterval
    frameCalculator = IconAnimationFrameCalculator()
    renderer = IconAnimationRenderer(iconSize: iconSize)
    idleIcon = renderer.idleIcon()
  }

  func startAnimation(style: AnimationStyle, color: CodableColor) {
    animationStart = clock.now()
    state = .animating(style: style, color: color)
    performanceGovernor.reset()
    delegate?.animationDidStart(style: style, color: color)
    startTimer()
  }

  func stopAnimation() {
    guard case .animating = state else { return }
    stopTimer()
    state = .idle
    delegate?.updateIcon(idleIcon)
    delegate?.animationDidEnd()
  }

  private func startTimer() {
    stopTimer()
    guard case .animating = state else { return }
    let timer = timerFactory()
    timer.start(interval: currentFrameInterval) { [weak self] in
      self?.tick()
    }
    self.timer = timer
  }

  private var currentFrameInterval: TimeInterval {
    switch performanceGovernor.state {
    case .normal:
      return normalFrameInterval

    case .reduced:
      return reducedFrameInterval
    }
  }

  private func stopTimer() {
    timer?.stop()
    timer = nil
  }

  private func tick() {
    guard case .animating(let style, let codableColor) = state else {
      stopTimer()
      return
    }

    let elapsed = clock.now() - animationStart
    let parameters = frameCalculator.parameters(for: style, elapsed: elapsed)
    debugLastParameters = parameters

    let image: NSImage
    var currentTimestamp = CACurrentMediaTime()
    var renderDuration: TimeInterval = 0

    if parameters.visible {
      let renderStart = currentTimestamp
      image = renderer.renderIcon(
        color: codableColor.toNSColor(),
        parameters: parameters
      )
      currentTimestamp = CACurrentMediaTime()
      renderDuration = currentTimestamp - renderStart
    } else {
      image = idleIcon
    }

    recordRenderDuration(renderDuration, timestamp: currentTimestamp)

    delegate?.updateIcon(image)
  }

  private func recordRenderDuration(_ duration: TimeInterval, timestamp: TimeInterval) {
    debugLastRenderDuration = duration
    let evaluation = AnimationFrameBudgetEvaluator.evaluate(
      duration: duration,
      frameBudget: frameBudget,
      lastWarning: lastBudgetWarning,
      timestamp: timestamp,
      handler: budgetExceededHandler
    )
    debugRenderBudgetExceeded = evaluation.exceeded
    lastBudgetWarning = evaluation.lastWarning

    applyPerformanceEvaluation(exceededBudget: evaluation.exceeded)
  }

  func simulateRenderDurationForTesting(_ duration: TimeInterval, timestamp: TimeInterval) {
    recordRenderDuration(duration, timestamp: timestamp)
  }

  private func applyPerformanceEvaluation(exceededBudget: Bool) {
    guard case .animating = state else { return }
    if let newState = performanceGovernor.recordFrame(exceededBudget: exceededBudget) {
      handlePerformanceStateChange(newState)
    }
  }

  private func handlePerformanceStateChange(_ newState: IconAnimationPerformanceGovernor.State) {
    restartTimerForPerformanceChange()
    switch newState {
    case .normal:
      logger.notice("Icon animation frame rate restored to 60fps after sustained recovery.")
    case .reduced:
      logger.notice("Icon animation frame rate reduced to 30fps after repeated budget overruns.")
    }
  }

  private func restartTimerForPerformanceChange() {
    guard case .animating = state else { return }
    startTimer()
  }
}

internal struct AnimationFrameBudgetEvaluator {
  internal struct Result {
    let exceeded: Bool
    let lastWarning: TimeInterval
  }

  static func evaluate(
    duration: TimeInterval,
    frameBudget: TimeInterval,
    lastWarning: TimeInterval,
    timestamp: TimeInterval,
    handler: (TimeInterval) -> Void
  ) -> Result {
    guard duration > frameBudget else {
      return Result(exceeded: false, lastWarning: lastWarning)
    }

    if timestamp - lastWarning > 1.0 {
      handler(duration)
      return Result(exceeded: true, lastWarning: timestamp)
    }

    return Result(exceeded: true, lastWarning: lastWarning)
  }
}

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
  private enum AnimationConstants {
    // Glow: 2s ease keeps motion gentle yet visible in peripheral vision.
    static let glowCycleDuration: TimeInterval = 2.0
    static let glowMinimumOpacity: CGFloat = 0.5
    static let glowOpacityRange: CGFloat = 0.5
    // Pulse: 1.5s cadence mimics a heartbeat with gentle scale/opacity offsets.
    static let pulseCycleDuration: TimeInterval = 1.5
    static let pulseBaseScale: CGFloat = 1.0
    static let pulseScaleAmplitude: CGFloat = 0.15
    static let pulseBaseOpacity: CGFloat = 0.85
    static let pulseOpacityRange: CGFloat = 0.15
    // Blink: half-second toggle provides urgency for high-priority matches.
    static let blinkInterval: TimeInterval = 0.5
  }

  internal struct FrameParameters: Equatable {
    let scale: CGFloat
    let opacity: CGFloat
    let visible: Bool
  }

  weak var delegate: IconAnimatorDelegate?

  private(set) var state: IconAnimationState = .idle

  private let iconSize: CGFloat
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

  /// The idle icon image displayed when no animation is active.
  let idleIcon: NSImage

  // Exposed for tests to assert frame progression.
  internal private(set) var debugLastParameters: FrameParameters?
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
    self.iconSize = iconSize
    self.timerFactory = timerFactory ?? { TimerAnimationTimer() }
    self.clock = clock ?? SystemAnimationClock()
    self.frameBudget = frameBudget
    if let budgetExceededHandler {
      self.budgetExceededHandler = budgetExceededHandler
    } else {
      self.budgetExceededHandler = { [logger] duration in
        logger.warning(
          "Icon frame rendering exceeded budget: \(duration * 1_000, format: .fixed(precision: 3)) ms"
        )
      }
    }
    performanceGovernor = IconAnimationPerformanceGovernor(
      fallbackViolationThreshold: fallbackViolationThreshold,
      recoveryFrameThreshold: recoveryFrameThreshold
    )
    self.reducedFrameInterval = reducedFrameInterval
    idleIcon = IconAnimator.renderIcon(
      size: iconSize,
      color: NSColor(calibratedWhite: 0.8, alpha: 1.0),
      parameters: FrameParameters(scale: 1.0, opacity: 1.0, visible: true)
    )
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
    let parameters = frameParameters(for: style, elapsed: elapsed)
    debugLastParameters = parameters

    let image: NSImage
    var currentTimestamp = CACurrentMediaTime()
    var renderDuration: TimeInterval = 0

    if parameters.visible {
      let renderStart = currentTimestamp
      image = IconAnimator.renderIcon(
        size: iconSize,
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

    if evaluation.exceeded {
      handleBudgetViolation()
    } else {
      handleHealthyFrame()
    }
  }

  func simulateRenderDurationForTesting(_ duration: TimeInterval, timestamp: TimeInterval) {
    recordRenderDuration(duration, timestamp: timestamp)
  }

  private func handleBudgetViolation() {
    guard case .animating = state else { return }
    consecutiveBudgetViolations += 1
    consecutiveHealthyFrames = 0

    switch performanceState {
    case .normal where consecutiveBudgetViolations >= fallbackViolationThreshold:
      enterReducedPerformanceMode()

    case .normal:
      break

    case .reduced:
      break
    }
  }

  private func handleHealthyFrame() {
    guard case .animating = state else { return }
    consecutiveBudgetViolations = 0

    switch performanceState {
    case .normal:
      consecutiveHealthyFrames = min(consecutiveHealthyFrames + 1, recoveryFrameThreshold)

    case .reduced:
      consecutiveHealthyFrames += 1
      if consecutiveHealthyFrames >= recoveryFrameThreshold {
        restoreNormalPerformance()
      }
    }
  }

  private func enterReducedPerformanceMode() {
    guard performanceState != .reduced else { return }
    performanceState = .reduced
    consecutiveBudgetViolations = 0
    consecutiveHealthyFrames = 0
    restartTimerForPerformanceChange()
    logger.notice("Icon animation frame rate reduced to 30fps after repeated budget overruns.")
  }

  private func restoreNormalPerformance() {
    guard performanceState == .reduced else { return }
    performanceState = .normal
    consecutiveHealthyFrames = 0
    restartTimerForPerformanceChange()
    logger.notice("Icon animation frame rate restored to 60fps after sustained recovery.")
  }

  private func restartTimerForPerformanceChange() {
    guard case .animating = state else { return }
    startTimer()
  }

  func frameParameters(for style: AnimationStyle, elapsed: TimeInterval) -> FrameParameters {
    switch style {
    case .glow:
      let cycle = normalizedCycle(
        elapsed: elapsed,
        duration: AnimationConstants.glowCycleDuration
      )
      let opacity = AnimationConstants.glowMinimumOpacity +
        cycle * AnimationConstants.glowOpacityRange
      return FrameParameters(scale: 1.0, opacity: opacity, visible: true)

    case .pulse:
      let cycle = normalizedCycle(
        elapsed: elapsed,
        duration: AnimationConstants.pulseCycleDuration
      )
      let scale = AnimationConstants.pulseBaseScale +
        cycle * AnimationConstants.pulseScaleAmplitude
      let opacity = AnimationConstants.pulseBaseOpacity +
        cycle * AnimationConstants.pulseOpacityRange
      return FrameParameters(scale: scale, opacity: opacity, visible: true)

    case .blink:
      let isOn = Int((elapsed / AnimationConstants.blinkInterval).rounded(.down)) % 2 == 0
      return FrameParameters(scale: 1.0, opacity: isOn ? 1.0 : 0.0, visible: isOn)
    }
  }

  private func normalizedCycle(elapsed: TimeInterval, duration: TimeInterval) -> CGFloat {
    let position = elapsed.truncatingRemainder(dividingBy: duration) / duration
    let normalized: Double
    if position <= 0.5 {
      normalized = position / 0.5
    } else {
      normalized = 1.0 - ((position - 0.5) / 0.5)
    }
    return CGFloat(max(0.0, min(1.0, normalized)))
  }

  private static func renderIcon(
    size: CGFloat,
    color: NSColor,
    parameters: FrameParameters
  ) -> NSImage {
    let dimension = CGSize(width: size, height: size)
    let image = NSImage(size: dimension)

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
      return image
    }

    context.clear(CGRect(origin: .zero, size: dimension))

    let baseDiameter = size * 0.6 * parameters.scale
    let origin = (size - baseDiameter) / 2.0
    let rect = CGRect(x: origin, y: origin, width: baseDiameter, height: baseDiameter)

    if parameters.opacity > 0 {
      let shadowColor = color.withAlphaComponent(parameters.opacity * 0.6).cgColor
      context.setShadow(
        offset: .zero,
        blur: size * 0.4 * parameters.scale,
        color: shadowColor
      )

      context.setFillColor(color.withAlphaComponent(parameters.opacity).cgColor)
      context.fillEllipse(in: rect)
    }

    return image
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

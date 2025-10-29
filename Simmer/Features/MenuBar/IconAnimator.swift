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
protocol IconAnimatorClock {
  func now() -> TimeInterval
}

@MainActor
protocol AnimationTimer: AnyObject {
  func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
  func stop()
}

@MainActor
final class TimerAnimationTimer: AnimationTimer {
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

struct SystemAnimationClock: IconAnimatorClock {
  func now() -> TimeInterval {
    CACurrentMediaTime()
  }
}

@MainActor
final class IconAnimator {
  struct FrameParameters: Equatable {
    let scale: CGFloat
    let opacity: CGFloat
    let visible: Bool
  }

  weak var delegate: IconAnimatorDelegate?

  private(set) var state: IconAnimationState = .idle

  private let iconSize: CGFloat
  private let frameInterval: TimeInterval = 1.0 / 60.0
  private let timerFactory: @MainActor () -> AnimationTimer
  private let clock: IconAnimatorClock
  private var timer: AnimationTimer?
  private var animationStart: TimeInterval = 0
  private let logger = Logger(subsystem: "com.quantierra.Simmer", category: "IconAnimator")
  private let frameBudget: TimeInterval
  private var lastBudgetWarning: TimeInterval = 0
  private let budgetExceededHandler: (TimeInterval) -> Void

  /// The idle icon image used when no animation is active
  let idleIcon: NSImage

  // Exposed for tests to assert frame progression.
  internal private(set) var debugLastParameters: FrameParameters?
  internal private(set) var debugLastRenderDuration: TimeInterval?
  internal private(set) var debugRenderBudgetExceeded = false

  init(
    iconSize: CGFloat = 18,
    timerFactory: (@MainActor () -> AnimationTimer)? = nil,
    clock: IconAnimatorClock? = nil,
    frameBudget: TimeInterval = 0.002,
    budgetExceededHandler: ((TimeInterval) -> Void)? = nil
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
    idleIcon = IconAnimator.renderIcon(
      size: iconSize,
      color: NSColor(calibratedWhite: 0.8, alpha: 1.0),
      parameters: FrameParameters(scale: 1.0, opacity: 1.0, visible: true)
    )
  }

  func startAnimation(style: AnimationStyle, color: CodableColor) {
    animationStart = clock.now()
    state = .animating(style: style, color: color)
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
    let timer = timerFactory()
    timer.start(interval: frameInterval) { [weak self] in
      self?.tick()
    }
    self.timer = timer
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
  }

  func simulateRenderDurationForTesting(_ duration: TimeInterval, timestamp: TimeInterval) {
    recordRenderDuration(duration, timestamp: timestamp)
  }

  func frameParameters(for style: AnimationStyle, elapsed: TimeInterval) -> FrameParameters {
    switch style {
    case .glow:
      let duration: TimeInterval = 2.0
      let cycle = normalizedCycle(elapsed: elapsed, duration: duration)
      let opacity = 0.5 + cycle * 0.5
      return FrameParameters(scale: 1.0, opacity: opacity, visible: true)
    case .pulse:
      let duration: TimeInterval = 1.5
      let cycle = normalizedCycle(elapsed: elapsed, duration: duration)
      let scale = 1.0 + cycle * 0.15
      let opacity = 0.85 + cycle * 0.15
      return FrameParameters(scale: scale, opacity: opacity, visible: true)
    case .blink:
      let interval: TimeInterval = 0.5
      let isOn = Int((elapsed / interval).rounded(.down)) % 2 == 0
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
      context.setShadow(
        offset: .zero,
        blur: size * 0.4 * parameters.scale,
        color: color.withAlphaComponent(parameters.opacity * 0.6).cgColor
      )

      context.setFillColor(color.withAlphaComponent(parameters.opacity).cgColor)
      context.fillEllipse(in: rect)
    }

    return image
  }
}

struct AnimationFrameBudgetEvaluator {
  struct Result {
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

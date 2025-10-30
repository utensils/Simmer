//
//  LogMonitorEventPipeline.swift
//  Simmer
//
//  Drives match dispatch and animation coordination for ``LogMonitor``.
//

import Foundation

@MainActor
internal final class LogMonitorEventPipeline: MatchEventHandlerDelegate {
  var onHistoryUpdate: (([MatchEvent]) -> Void)?
  var onWarningsUpdate: (([FrequentMatchWarning]) -> Void)?
  var onLatencyMeasured: ((TimeInterval) -> Void)?

  private let stateStore: LogMonitorStateStore
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let animationTracker: LogMonitorAnimationTracker
  private let dateProvider: () -> Date
  private let debounceInterval: TimeInterval

  init(
    stateStore: LogMonitorStateStore,
    matchEventHandler: MatchEventHandler,
    iconAnimator: IconAnimator,
    animationTracker: LogMonitorAnimationTracker,
    dateProvider: @escaping () -> Date,
    debounceInterval: TimeInterval
  ) {
    self.stateStore = stateStore
    self.matchEventHandler = matchEventHandler
    self.iconAnimator = iconAnimator
    self.animationTracker = animationTracker
    self.dateProvider = dateProvider
    self.debounceInterval = debounceInterval
    self.matchEventHandler.delegate = self
  }

  func processMatch(
    patternID: UUID,
    line: String,
    lineNumber: Int,
    filePath: String
  ) {
    guard let pattern = stateStore.pattern(for: patternID) else { return }
    matchEventHandler.handleMatch(
      pattern: pattern,
      line: line,
      lineNumber: lineNumber,
      filePath: filePath,
      priority: stateStore.priority(for: patternID)
    )
  }

  func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
    guard let pattern = stateStore.pattern(for: event.patternID) else { return }
    let timestamp = dateProvider()

    guard animationTracker.shouldTriggerAnimation(
      for: event.patternID,
      priority: event.priority,
      timestamp: timestamp,
      isIconIdle: iconAnimator.state == .idle,
      debounceInterval: debounceInterval
    ) else {
      return
    }

    iconAnimator.startAnimation(style: pattern.animationStyle, color: pattern.color)
    animationTracker.recordAnimationStart(
      for: event.patternID,
      priority: event.priority,
      timestamp: timestamp
    )

    if let startDate = animationTracker.dequeueLatencyStart(for: event.patternID) {
      onLatencyMeasured?(dateProvider().timeIntervalSince(startDate))
    }
  }

  func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
    onHistoryUpdate?(historyDidUpdate)
  }

  func matchEventHandler(
    _ handler: MatchEventHandler,
    didUpdateWarnings warnings: [FrequentMatchWarning]
  ) {
    onWarningsUpdate?(warnings)
  }
}

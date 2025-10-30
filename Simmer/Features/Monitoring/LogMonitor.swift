//
//  LogMonitor.swift
//  Simmer
//
//  Coordinates file watchers, pattern matching, and animation feedback.
//

import Foundation
import os.log

/// Coordinates file watching, pattern evaluation, and menu feedback.
@MainActor
internal protocol LogMonitoring: AnyObject {
  func reloadPatterns()
  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool)
}

@MainActor
internal final class LogMonitor: NSObject {
  typealias WatcherFactory = (LogPattern) -> FileWatching

  private let configurationStore: ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let watcherFactory: WatcherFactory
  private let processingQueue: DispatchQueue
  private let alertPresenter: LogMonitorAlertPresenting
  private let notificationCenter: NotificationCenter
  private let dateProvider: () -> Date
  private let logger = OSLog(subsystem: "io.utensils.Simmer", category: "LogMonitor")

  private let stateStore = LogMonitorStateStore(
    queueLabel: "io.utensils.Simmer.log-monitor.state"
  )
  private let animationTracker = LogMonitorAnimationTracker(
    queueLabel: "io.utensils.Simmer.log-monitor.animation"
  )
  private lazy var patternValidator = LogMonitorPatternAccessValidator(
    configurationStore: self.configurationStore,
    alertPresenter: self.alertPresenter,
    logger: self.logger,
    notifyPatternsDidChange: { [weak self] in self?.notifyPatternsDidChange() }
  )
  private lazy var watcherCoordinator = LogMonitorWatcherCoordinator(
    stateStore: self.stateStore,
    patternValidator: self.patternValidator,
    watcherFactory: self.watcherFactory,
    alertPresenter: self.alertPresenter,
    logger: self.logger,
    maxWatcherCount: self.maxWatcherCount
  )
  private lazy var eventPipeline = LogMonitorEventPipeline(
    stateStore: self.stateStore,
    matchEventHandler: self.matchEventHandler,
    iconAnimator: self.iconAnimator,
    animationTracker: self.animationTracker,
    dateProvider: self.dateProvider,
    debounceInterval: self.debounceInterval
  )

  private let maxWatcherCount = 20
  private let debounceInterval: TimeInterval = 0.1
  private var didBootstrapPatterns = false

  var events: MatchEventHandler { matchEventHandler }
  var onHistoryUpdate: (([MatchEvent]) -> Void)? {
    get { eventPipeline.onHistoryUpdate }
    set { eventPipeline.onHistoryUpdate = newValue }
  }
  var onWarningsUpdate: (([FrequentMatchWarning]) -> Void)? {
    get { eventPipeline.onWarningsUpdate }
    set { eventPipeline.onWarningsUpdate = newValue }
  }
  var onLatencyMeasured: ((TimeInterval) -> Void)? {
    get { eventPipeline.onLatencyMeasured }
    set { eventPipeline.onLatencyMeasured = newValue }
  }

  @MainActor
  init(
    configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
    patternMatcher: PatternMatcherProtocol? = nil,
    matchEventHandler: MatchEventHandler,
    iconAnimator: IconAnimator,
    watcherFactory: WatcherFactory? = nil,
    dateProvider: @escaping () -> Date = Date.init,
    processingQueue: DispatchQueue = DispatchQueue(
      label: "io.utensils.Simmer.log-monitor.processing",
      qos: .userInitiated
    ),
    alertPresenter: LogMonitorAlertPresenting? = nil,
    notificationCenter: NotificationCenter = .default
  ) {
    self.configurationStore = configurationStore
    self.patternMatcher = patternMatcher ?? RegexPatternMatcher()
    self.matchEventHandler = matchEventHandler
    self.iconAnimator = iconAnimator
    self.watcherFactory = watcherFactory ?? { FileWatcher(path: $0.logPath) }
    self.dateProvider = dateProvider
    self.processingQueue = processingQueue
    self.alertPresenter = alertPresenter ?? NSAlertPresenter()
    self.notificationCenter = notificationCenter
    super.init()
    _ = self.eventPipeline
    self.bootstrapInitialPatterns()
  }

  @MainActor
  func reloadPatterns() {
    configureWatchers(for: configurationStore.loadPatterns().filter(\.enabled))
    notifyPatternsDidChange()
  }

  @MainActor
  func start() {
    guard !didBootstrapPatterns else { return }
    configureWatchers(for: configurationStore.loadPatterns().filter(\.enabled))
    didBootstrapPatterns = true
    notifyPatternsDidChange()
  }

  @MainActor
  func stopAll() {
    let watchers = watcherCoordinator.removeAllWatchers()
    watchers.forEach { $0.stop() }
    animationTracker.reset()
    Task { @MainActor [iconAnimator] in iconAnimator.stopAnimation() }
  }

  @MainActor
  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool) {
    if isEnabled {
      reloadPatterns()
    } else {
      stateStore.suppressAlerts(for: patternID)
      reloadPatterns()
      stateStore.unsuppressAlerts(for: patternID)
    }
  }

  @MainActor
  private func bootstrapInitialPatterns() {
    configureWatchers(for: configurationStore.loadPatterns().filter(\.enabled))
    didBootstrapPatterns = true
  }

  @MainActor
  private func configureWatchers(for patterns: [LogPattern]) {
    let factory = LogMonitorWatcherHandlerFactory(
      stateStore: stateStore,
      processingQueue: processingQueue,
      matchContextBuilder: { [weak self] patternID in
        guard let self else { return nil }
        return LogMonitorMatchContext(
          patternMatcher: self.patternMatcher,
          stateStore: self.stateStore,
          animationTracker: self.animationTracker,
          dateProvider: self.dateProvider,
          onMatch: { [weak self] patternID, line, number, path in
            guard let self else { return }
            self.eventPipeline.processMatch(
              patternID: patternID,
              line: line,
              lineNumber: number,
              filePath: path
            )
          }
        )
      },
      errorContextBuilder: { [weak self] in
        guard let self else { return nil }
        return LogMonitorWatcherErrorContext(
          stateStore: self.stateStore,
          patternValidator: self.patternValidator,
          alertPresenter: self.alertPresenter,
          logger: self.logger,
          removeWatcher: { [weak self] id in self?.watcherCoordinator.removeWatcher(for: id) },
          reloadPatterns: { [weak self] in self?.reloadPatterns() }
        )
      }
    )

    let handlers = factory.makeHandlers()
    watcherCoordinator.configureWatchers(
      for: patterns,
      onRead: handlers.onRead,
      onError: handlers.onError
    )
  }

  private func notifyPatternsDidChange() {
    notificationCenter.post(name: .logMonitorPatternsDidChange, object: self)
  }
}

// MARK: - LogMonitoring

extension LogMonitor: LogMonitoring {}

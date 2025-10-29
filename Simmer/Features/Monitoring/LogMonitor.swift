//
//  LogMonitor.swift
//  Simmer
//
//  Coordinates file watchers, pattern matching, and animation feedback.
//

import Foundation
import os.log

/// Central coordinator that listens to file changes, evaluates patterns, and triggers visual feedback.
protocol LogMonitoring: AnyObject {
  func reloadPatterns()
  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool)
}

final class LogMonitor: NSObject {
  typealias WatcherFactory = (LogPattern) -> FileWatching

  private let configurationStore: ConfigurationStoreProtocol
  private let fileAccessManager: FileAccessManaging
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let watcherFactory: WatcherFactory
  private let stateQueue = DispatchQueue(label: "com.quantierra.Simmer.log-monitor")
  private let logger = OSLog(subsystem: "com.quantierra.Simmer", category: "LogMonitor")
  private let processingQueue: DispatchQueue
  private let alertPresenter: LogMonitorAlertPresenting
  private let notificationCenter: NotificationCenter
  private let maxWatcherCount = 20
  private let debounceInterval: TimeInterval = 0.1
  private let dateProvider: () -> Date

  private struct WatchContext {
    var pattern: LogPattern
    var lineCount: Int
  }

  private struct WatchEntry {
    var watcher: FileWatching
    var context: WatchContext
  }

  private var entriesByPatternID: [UUID: WatchEntry] = [:]
  private var watcherIdentifiers: [ObjectIdentifier: UUID] = [:]
  private var patternPriorities: [UUID: Int] = [:]
  private var lastAnimationTimestamps: [UUID: Date] = [:]
  private var currentAnimation: (patternID: UUID, priority: Int)?
  private var activeBookmarkURLs: [UUID: URL] = [:]
  private var didBootstrapPatterns = false
  private var suppressedAlertPatternIDs: Set<UUID> = []

  @MainActor
  init(
    configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
    fileAccessManager: FileAccessManaging? = nil,
    patternMatcher: PatternMatcherProtocol? = nil,
    matchEventHandler: MatchEventHandler,
    iconAnimator: IconAnimator,
    watcherFactory: WatcherFactory? = nil,
    dateProvider: @escaping () -> Date = Date.init,
    processingQueue: DispatchQueue = DispatchQueue(
      label: "com.quantierra.Simmer.log-monitor.processing",
      qos: .userInitiated
    ),
    alertPresenter: LogMonitorAlertPresenting? = nil,
    notificationCenter: NotificationCenter = .default
  ) {
    self.configurationStore = configurationStore
    self.fileAccessManager = fileAccessManager ?? FileAccessManager()
    self.patternMatcher = patternMatcher ?? RegexPatternMatcher()
    self.matchEventHandler = matchEventHandler
    self.iconAnimator = iconAnimator
    self.watcherFactory = watcherFactory ?? { pattern in
      FileWatcher(path: pattern.logPath)
    }
    self.dateProvider = dateProvider
    self.processingQueue = processingQueue
    self.alertPresenter = alertPresenter ?? NSAlertPresenter()
    self.notificationCenter = notificationCenter
    super.init()
    self.matchEventHandler.delegate = self
    bootstrapInitialPatterns()
  }

  /// Exposes the match event handler for UI components that need history access.
  var events: MatchEventHandler {
    matchEventHandler
  }

  /// Invoked on the main actor whenever match history changes.
  @MainActor
  var onHistoryUpdate: (([MatchEvent]) -> Void)?

  @MainActor
  private func bootstrapInitialPatterns() {
    let persisted = configurationStore.loadPatterns().filter(\.enabled)
    configureWatchers(for: persisted)
    didBootstrapPatterns = true
  }

  /// Reloads patterns from storage and reconciles active watchers.
  @MainActor
  func reloadPatterns() {
    let patterns = configurationStore.loadPatterns()
    configureWatchers(for: patterns.filter(\.enabled))
    notifyPatternsDidChange()
  }

  deinit {
    stopAll()
  }

  /// Loads persisted patterns and begins monitoring enabled entries.
  @MainActor
  func start() {
    let patterns = configurationStore.loadPatterns().filter(\.enabled)
    configureWatchers(for: patterns)
    didBootstrapPatterns = true
    notifyPatternsDidChange()
  }

  /// Stops all active watchers and clears internal state.
  func stopAll() {
    let result: ([FileWatching], [URL]) = stateQueue.sync {
      let currentWatchers = entriesByPatternID.values.map(\.watcher)
      let bookmarkURLs = Array(activeBookmarkURLs.values)
      entriesByPatternID.removeAll()
      watcherIdentifiers.removeAll()
      patternPriorities.removeAll()
      lastAnimationTimestamps.removeAll()
      currentAnimation = nil
      activeBookmarkURLs.removeAll()
      suppressedAlertPatternIDs.removeAll()
      return (currentWatchers, bookmarkURLs)
    }
    let activeWatchers = result.0
    let bookmarkURLs = result.1

    activeWatchers.forEach { $0.stop() }
    bookmarkURLs.forEach { $0.stopAccessingSecurityScopedResource() }

    Task { @MainActor [iconAnimator] in
      iconAnimator.stopAnimation()
    }
  }

  /// Updates monitoring state when a pattern is toggled in settings.
  @MainActor
  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool) {
    if isEnabled {
      reloadPatterns()
    } else {
      suppressAlerts(for: patternID)
      reloadPatterns()
      unsuppressAlerts(for: patternID)
    }
  }

  private func notifyPatternsDidChange() {
    notificationCenter.post(name: .logMonitorPatternsDidChange, object: self)
  }

  @MainActor
  private func configureWatchers(for patterns: [LogPattern]) {
    let preparedPatterns = preparePatterns(patterns)
    let limitedPatterns = Array(preparedPatterns.prefix(maxWatcherCount))
    if preparedPatterns.count > maxWatcherCount {
      os_log(
        .error,
        log: logger,
        "Watcher limit exceeded (%{public}d > %{public}d). Additional patterns will not be monitored.",
        preparedPatterns.count,
        maxWatcherCount
      )
    }

    let priorities = Dictionary(uniqueKeysWithValues: limitedPatterns.enumerated().map { ($1.id, $0) })

    let identifiersToRemove: [UUID] = stateQueue.sync {
      patternPriorities = priorities
      let existingIDs = Set(entriesByPatternID.keys)
      let incomingIDs = Set(limitedPatterns.map(\.id))
      return Array(existingIDs.subtracting(incomingIDs))
    }

    identifiersToRemove.forEach { removeWatcher(forPatternID: $0) }

    for pattern in limitedPatterns {
      if updatePattern(pattern) { continue }
      addWatcher(for: pattern)
    }
  }

  @MainActor
  private func preparePatterns(_ patterns: [LogPattern]) -> [LogPattern] {
    patterns.compactMap { pattern in
      preparePatternForMonitoring(pattern)
    }
  }

  @MainActor
  private func preparePatternForMonitoring(_ pattern: LogPattern) -> LogPattern? {
    guard let bookmark = pattern.bookmark else {
      return pattern
    }

    do {
      let (url, isStale) = try fileAccessManager.resolveBookmark(bookmark)
      if isStale {
        return handleStaleBookmark(for: pattern, bookmark: bookmark)
      }

      return registerBookmarkAccessIfNeeded(url: url, for: pattern)
    } catch {
      handleBookmarkResolutionFailure(pattern: pattern, error: error)
      return nil
    }
  }

  @MainActor
  private func handleStaleBookmark(
    for pattern: LogPattern,
    bookmark: FileBookmark
  ) -> LogPattern? {
    do {
      let refreshed = try fileAccessManager.refreshStaleBookmark(bookmark)
      var updatedPattern = pattern
      updatedPattern.bookmark = refreshed
      updatedPattern.logPath = refreshed.filePath

      do {
        try configurationStore.updatePattern(updatedPattern)
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to persist refreshed bookmark for pattern '%{public}@': %{public}@",
          pattern.name,
          String(describing: error)
        )
      }

      do {
        let (url, isStillStale) = try fileAccessManager.resolveBookmark(refreshed)
        guard !isStillStale else {
          os_log(
            .error,
            log: logger,
            "Bookmark for pattern '%{public}@' remained stale after refresh",
            pattern.name
          )
          disablePattern(updatedPattern, message: """
          Simmer still cannot access "\(updatedPattern.logPath)" after refreshing permissions. Try selecting the file again in Settings.
          """)
          return nil
        }

        return registerBookmarkAccessIfNeeded(url: url, for: updatedPattern)
      } catch {
        handleBookmarkResolutionFailure(pattern: updatedPattern, error: error)
        return nil
      }
    } catch {
      handleBookmarkRefreshFailure(pattern: pattern, error: error)
      return nil
    }
  }

  @MainActor
  private func registerBookmarkAccessIfNeeded(
    url: URL,
    for pattern: LogPattern
  ) -> LogPattern? {
    let existingURL: URL? = stateQueue.sync {
      activeBookmarkURLs[pattern.id]
    }

    if let current = existingURL, current == url {
      return pattern
    }

    if let current = existingURL {
      current.stopAccessingSecurityScopedResource()
    }

    var updatedPattern = pattern
    updatedPattern.logPath = url.path

    if url.startAccessingSecurityScopedResource() {
      stateQueue.sync {
        activeBookmarkURLs[pattern.id] = url
      }
    } else {
      os_log(
        .info,
        log: logger,
        "Security-scoped access unavailable for pattern '%{public}@'. Continuing without bookmark activation.",
        pattern.name
      )
      stateQueue.sync {
        activeBookmarkURLs.removeValue(forKey: pattern.id)
      }
    }

    return updatedPattern
  }

  @MainActor
  private func handleBookmarkResolutionFailure(pattern: LogPattern, error: Error) {
    if isAlertSuppressed(for: pattern.id) {
      return
    }

    os_log(
      .error,
      log: logger,
      "Failed to resolve bookmark for pattern '%{public}@': %{public}@",
      pattern.name,
      String(describing: error)
    )
    disablePattern(pattern, message: """
    Simmer lost access to "\(pattern.logPath)". Select the file again in Settings to resume monitoring.
    """)
  }

  @MainActor
  private func handleBookmarkRefreshFailure(pattern: LogPattern, error: Error) {
    if let accessError = error as? FileAccessError, accessError == .userCancelled {
      os_log(
        .info,
        log: logger,
        "User cancelled bookmark refresh for pattern '%{public}@'",
        pattern.name
      )
      disablePattern(pattern, message: """
      Access to "\(pattern.logPath)" needs to be renewed before monitoring can continue. Open Settings and reselect the file.
      """)
      return
    }

    os_log(
      .error,
      log: logger,
      "Failed to refresh bookmark for pattern '%{public}@': %{public}@",
      pattern.name,
      String(describing: error)
    )
    disablePattern(pattern, message: """
    Simmer could not refresh access to "\(pattern.logPath)". Try selecting the file again from Settings.
    """)
  }

  @MainActor
  private func disablePattern(_ pattern: LogPattern, message: String) {
    var updatedPattern = pattern
    if updatedPattern.enabled {
      updatedPattern.enabled = false
      do {
        try configurationStore.updatePattern(updatedPattern)
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to disable pattern '%{public}@' after access error: %{public}@",
          pattern.name,
          String(describing: error)
        )
      }
    }

    alertPresenter.presentAlert(
      title: "File access required",
      message: message
    )
    notifyPatternsDidChange()
  }

  private func process(
    lines: [String],
    patternID: UUID,
    filePath: String
  ) {
    guard let context = context(for: patternID) else { return }

    var nextLineNumber = context.lineCount
    var matches: [(line: String, lineNumber: Int)] = []

    for line in lines {
      nextLineNumber += 1
      if patternMatcher.match(line: line, pattern: context.pattern) != nil {
        matches.append((line: line, lineNumber: nextLineNumber))
      }
    }

    updateLineCount(for: patternID, count: nextLineNumber)

    guard !matches.isEmpty else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      for match in matches {
        self.handleMatch(
          patternID: patternID,
          line: match.line,
          lineNumber: match.lineNumber,
          filePath: filePath
        )
      }
    }
  }

  private func handleWatcherError(
    patternID: UUID,
    error: FileWatcherError,
    filePath: String
  ) {
    if isAlertSuppressed(for: patternID) {
      removeWatcher(forPatternID: patternID)
      return
    }

    guard let entry = removeWatcher(forPatternID: patternID) else { return }

    var pattern = entry.context.pattern
    let patternName = pattern.name

    os_log(
      .error,
      log: logger,
      "Watcher error for pattern '%{public}@' at path '%{public}@': %{public}@",
      patternName,
      pattern.logPath,
      String(describing: error)
    )

    if pattern.enabled {
      pattern.enabled = false
      do {
        try configurationStore.updatePattern(pattern)
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to disable pattern '%{public}@' after watcher error: %{public}@",
          patternName,
          String(describing: error)
        )
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let message = self.alertMessage(
        for: error,
        patternName: patternName,
        filePath: filePath
      )
      self.alertPresenter.presentAlert(
        title: "Monitoring paused for \(patternName)",
        message: message
      )
      self.reloadPatterns()
    }
  }

  private func alertMessage(
    for error: FileWatcherError,
    patternName: String,
    filePath: String
  ) -> String {
    switch error {
    case .fileDeleted:
      return """
      Simmer stopped monitoring "\(patternName)" because "\(filePath)" is missing. \
      Restore the file or choose a new path in Settings, then re-enable the pattern.
      """
    case .permissionDenied:
      return """
      Simmer no longer has permission to read "\(filePath)" for pattern "\(patternName)". \
      Update permissions or select a new file in Settings before re-enabling the pattern.
      """
    case .fileDescriptorInvalid:
      return """
      Simmer hit an unexpected error while reading "\(filePath)" for pattern "\(patternName)". \
      Verify the file is accessible and try re-enabling the pattern from Settings.
      """
    }
  }

  private func addWatcher(for pattern: LogPattern) {
    let watcher = watcherFactory(pattern)
    watcher.delegate = self
    let stored = stateQueue.sync { () -> Bool in
      guard entriesByPatternID.count < maxWatcherCount else { return false }
      let context = WatchContext(pattern: pattern, lineCount: 0)
      let entry = WatchEntry(watcher: watcher, context: context)
      entriesByPatternID[pattern.id] = entry
      watcherIdentifiers[ObjectIdentifier(watcher)] = pattern.id
      return true
    }

    guard stored else {
      os_log(
        .error,
        log: logger,
        "Watcher limit reached. Unable to monitor pattern '%{public}@' at path '%{public}@'.",
        pattern.name,
        pattern.logPath
      )
      return
    }

    do {
      try watcher.start()
    } catch {
      os_log(
        .error,
        log: logger,
        "Failed to start watcher for pattern '%{public}@' at path '%{public}@': %{public}@",
        pattern.name,
        pattern.logPath,
        String(describing: error)
      )
      removeWatcher(forPatternID: pattern.id)
    }
  }

  @discardableResult
  private func updatePattern(_ pattern: LogPattern) -> Bool {
    let restartNeeded: Bool? = stateQueue.sync {
      guard var entry = entriesByPatternID[pattern.id] else { return nil }
      let needsRestart = entry.context.pattern.logPath != pattern.logPath
      entry.context.pattern = pattern
      entriesByPatternID[pattern.id] = entry
      return needsRestart
    }

    guard let restartNeeded else { return false }

    if restartNeeded {
      removeWatcher(forPatternID: pattern.id)
      addWatcher(for: pattern)
    }

    return true
  }

  @discardableResult
  private func removeWatcher(forPatternID patternID: UUID) -> WatchEntry? {
    let result: (WatchEntry?, URL?) = stateQueue.sync {
      guard let entry = entriesByPatternID.removeValue(forKey: patternID) else { return (nil, nil) }
      watcherIdentifiers.removeValue(forKey: ObjectIdentifier(entry.watcher))
      lastAnimationTimestamps.removeValue(forKey: patternID)
      if currentAnimation?.patternID == patternID {
        currentAnimation = nil
      }
      suppressedAlertPatternIDs.remove(patternID)
      let bookmarkURL = activeBookmarkURLs.removeValue(forKey: patternID)
      return (entry, bookmarkURL)
    }

    let entry = result.0
    let bookmarkURL = result.1

    entry?.watcher.stop()
    bookmarkURL?.stopAccessingSecurityScopedResource()
    return entry
  }

  private func hasWatcher(for patternID: UUID) -> Bool {
    stateQueue.sync { entriesByPatternID[patternID] != nil }
  }

  private func patternID(for watcher: FileWatching) -> UUID? {
    stateQueue.sync { watcherIdentifiers[ObjectIdentifier(watcher)] }
  }

  private func context(for patternID: UUID) -> WatchContext? {
    stateQueue.sync { entriesByPatternID[patternID]?.context }
  }

  private func updateLineCount(for patternID: UUID, count: Int) {
    stateQueue.sync {
      guard var entry = entriesByPatternID[patternID] else { return }
      entry.context.lineCount = count
      entriesByPatternID[patternID] = entry
    }
  }

  private func pattern(for event: MatchEvent) -> LogPattern? {
    stateQueue.sync { entriesByPatternID[event.patternID]?.context.pattern }
  }

  private func priority(for patternID: UUID) -> Int {
    stateQueue.sync { patternPriorities[patternID] ?? Int.max }
  }

  @MainActor
  private func shouldTriggerAnimation(
    for patternID: UUID,
    priority: Int,
    timestamp: Date
  ) -> Bool {
    if iconAnimator.state == .idle {
      stateQueue.sync { currentAnimation = nil }
    }

    let lastForPattern = stateQueue.sync { lastAnimationTimestamps[patternID] }
    if let last = lastForPattern, timestamp.timeIntervalSince(last) < debounceInterval {
      return false
    }

    let current = stateQueue.sync { currentAnimation }
    guard let current else {
      return true
    }

    if priority < current.priority {
      return true
    }

    if current.patternID == patternID {
      return true
    }

    return iconAnimator.state == .idle
  }

  @MainActor
  private func recordAnimationStart(for patternID: UUID, priority: Int, timestamp: Date) {
    stateQueue.sync {
      currentAnimation = (patternID: patternID, priority: priority)
      lastAnimationTimestamps[patternID] = timestamp
    }
  }

  private func suppressAlerts(for patternID: UUID) {
    stateQueue.sync {
      suppressedAlertPatternIDs.insert(patternID)
    }
  }

  private func unsuppressAlerts(for patternID: UUID) {
    stateQueue.sync {
      suppressedAlertPatternIDs.remove(patternID)
    }
  }

  private func isAlertSuppressed(for patternID: UUID) -> Bool {
    stateQueue.sync {
      suppressedAlertPatternIDs.contains(patternID)
    }
  }
}

// MARK: - FileWatcherDelegate

extension LogMonitor: FileWatcherDelegate {
  func fileWatcher(_ watcher: FileWatching, didReadLines lines: [String]) {
    guard !lines.isEmpty, let patternID = patternID(for: watcher) else { return }

    processingQueue.async { [weak self] in
      self?.process(
        lines: lines,
        patternID: patternID,
        filePath: watcher.path
      )
    }
  }

  func fileWatcher(_ watcher: FileWatching, didEncounterError error: FileWatcherError) {
    guard let patternID = patternID(for: watcher) else { return }
    processingQueue.async { [weak self] in
      self?.handleWatcherError(
        patternID: patternID,
        error: error,
        filePath: watcher.path
      )
    }
  }
}

// MARK: - MatchEventHandlerDelegate

@MainActor
private extension LogMonitor {
  func handleMatch(
    patternID: UUID,
    line: String,
    lineNumber: Int,
    filePath: String
  ) {
    guard let pattern = pattern(forPatternID: patternID) else { return }
    let priorityValue = priority(for: patternID)

    matchEventHandler.handleMatch(
      pattern: pattern,
      line: line,
      lineNumber: lineNumber,
      filePath: filePath,
      priority: priorityValue
    )
  }

  func pattern(forPatternID patternID: UUID) -> LogPattern? {
    stateQueue.sync { entriesByPatternID[patternID]?.context.pattern }
  }
}

extension LogMonitor: MatchEventHandlerDelegate {
  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, didDetectMatch event: MatchEvent) {
    guard let pattern = pattern(for: event) else { return }
    let timestamp = dateProvider()
    guard shouldTriggerAnimation(for: event.patternID, priority: event.priority, timestamp: timestamp) else {
      return
    }
    iconAnimator.startAnimation(style: pattern.animationStyle, color: pattern.color)
    recordAnimationStart(for: event.patternID, priority: event.priority, timestamp: timestamp)
  }

  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
    onHistoryUpdate?(historyDidUpdate)
  }
}

extension LogMonitor: LogMonitoring {}

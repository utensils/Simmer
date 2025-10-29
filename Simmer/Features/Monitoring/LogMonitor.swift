//
//  LogMonitor.swift
//  Simmer
//
//  Coordinates file watchers, pattern matching, and animation feedback.
//

import Foundation
import os.log

/// Central coordinator that listens to file changes, evaluates patterns, and triggers visual feedback.
internal protocol LogMonitoring: AnyObject {
  func reloadPatterns()
  func setPatternEnabled(_ patternID: UUID, isEnabled: Bool)
}

internal final class LogMonitor: NSObject {
  typealias WatcherFactory = (LogPattern) -> FileWatching

  private let configurationStore: ConfigurationStoreProtocol
  private let patternMatcher: PatternMatcherProtocol
  private let matchEventHandler: MatchEventHandler
  private let iconAnimator: IconAnimator
  private let watcherFactory: WatcherFactory
  private let stateQueue = DispatchQueue(label: "io.utensils.Simmer.log-monitor")
  private let logger = OSLog(subsystem: "io.utensils.Simmer", category: "LogMonitor")
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
  private var didBootstrapPatterns = false
  private var suppressedAlertPatternIDs: Set<UUID> = []
  /// Start timestamps for pending latency measurements; access is synchronized via `stateQueue`.
  private var pendingLatencyStartDates: [UUID: [Date]] = [:]
  private var didWarnAboutPatternLimit = false

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

  /// Invoked on the main actor whenever high-frequency warnings change.
  @MainActor
  var onWarningsUpdate: (([FrequentMatchWarning]) -> Void)?

  /// Invoked on the main actor whenever a match produces icon feedback, reporting elapsed time.
  @MainActor
  var onLatencyMeasured: ((TimeInterval) -> Void)?

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
    let activeWatchers: [FileWatching] = stateQueue.sync {
      let currentWatchers = entriesByPatternID.values.map(\.watcher)
      entriesByPatternID.removeAll()
      watcherIdentifiers.removeAll()
      patternPriorities.removeAll()
      lastAnimationTimestamps.removeAll()
      currentAnimation = nil
      suppressedAlertPatternIDs.removeAll()
      return currentWatchers
    }

    activeWatchers.forEach { $0.stop() }

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
      presentPatternLimitAlert(totalPatternCount: preparedPatterns.count)
    } else {
      didWarnAboutPatternLimit = false
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
    return validateManualPatternAccess(for: pattern)
  }

  @MainActor
  private func validateManualPatternAccess(for pattern: LogPattern) -> LogPattern? {
    var updatedPattern = pattern
    let expandedPath = PathExpander.expand(pattern.logPath)

    if expandedPath != pattern.logPath {
      updatedPattern.logPath = expandedPath
      do {
        try configurationStore.updatePattern(updatedPattern)
      } catch {
        os_log(
          .error,
          log: logger,
          "Failed to persist expanded path '%{public}@' for pattern '%{public}@': %{public}@",
          expandedPath,
          pattern.name,
          String(describing: error)
        )
      }
    }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
      os_log(
        .error,
        log: logger,
        "Manual path validation failed for pattern '%{public}@': file missing at '%{public}@'",
        updatedPattern.name,
        expandedPath
      )
      disablePattern(
        updatedPattern,
        message: """
        Simmer cannot find "\(expandedPath)". Verify the file exists, then re-enable \
        "\(updatedPattern.name)" in Settings.
        """
      )
      return nil
    }

    if isDirectory.boolValue {
      os_log(
        .error,
        log: logger,
        "Manual path validation failed for pattern '%{public}@': directory supplied at '%{public}@'",
        updatedPattern.name,
        expandedPath
      )
      disablePattern(
        updatedPattern,
        message: """
        Simmer can only monitor files. Select a log file instead of "\(expandedPath)" before \
        re-enabling "\(updatedPattern.name)".
        """
      )
      return nil
    }

    guard fileManager.isReadableFile(atPath: expandedPath) else {
      os_log(
        .error,
        log: logger,
        "Manual path validation failed for pattern '%{public}@': unreadable file at '%{public}@'",
        updatedPattern.name,
        expandedPath
      )
      disablePattern(
        updatedPattern,
        message: """
        Simmer cannot read "\(expandedPath)". Check file permissions, then re-enable \
        "\(updatedPattern.name)" in Settings.
        """
      )
      return nil
    }

    return updatedPattern
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

    recordLatencyStart(for: patternID, matchCount: matches.count)

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
      Simmer stopped monitoring "\(patternName)" because "\(filePath)" is missing. Restore the \
      file or choose a new path in Settings, then re-enable the pattern.
      """

    case .permissionDenied:
      return """
      Simmer no longer has permission to read "\(filePath)" for pattern "\(patternName)". Update \
      permissions or choose a new file in Settings before re-enabling the pattern.
      """

    case .fileDescriptorInvalid:
      return """
      Simmer hit an unexpected error while reading "\(filePath)" for pattern "\(patternName)". \
      Verify the file is accessible and re-enable the pattern in Settings.
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
    let entry: WatchEntry? = stateQueue.sync {
      guard let entry = entriesByPatternID.removeValue(forKey: patternID) else { return nil }
      watcherIdentifiers.removeValue(forKey: ObjectIdentifier(entry.watcher))
      lastAnimationTimestamps.removeValue(forKey: patternID)
      if currentAnimation?.patternID == patternID {
        currentAnimation = nil
      }
      suppressedAlertPatternIDs.remove(patternID)
      return entry
    }

    entry?.watcher.stop()
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

  func fileWatcher(
    _ watcher: FileWatching,
    didEncounterError error: FileWatcherError
  ) {
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

  /// Records the time when a match is detected on the processing queue.
  /// Access stays synchronized via `stateQueue` to avoid racing with animation callbacks.
  nonisolated func recordLatencyStart(for patternID: UUID, matchCount: Int) {
    let timestamp = dateProvider()
    stateQueue.sync {
      var queue = pendingLatencyStartDates[patternID] ?? []
      for _ in 0..<matchCount {
        queue.append(timestamp)
      }
      pendingLatencyStartDates[patternID] = queue
    }
  }

  func dequeueLatencyStart(for patternID: UUID) -> Date? {
    // Animation callbacks run on the main actor; this stateQueue guard prevents cross-queue races.
    stateQueue.sync {
      guard var queue = pendingLatencyStartDates[patternID], !queue.isEmpty else {
        return nil
      }
      let start = queue.removeFirst()
      pendingLatencyStartDates[patternID] = queue.isEmpty ? nil : queue
      return start
    }
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
    if let startDate = dequeueLatencyStart(for: event.patternID) {
      let latency = dateProvider().timeIntervalSince(startDate)
      onLatencyMeasured?(latency)
    }
  }

  @MainActor
  func matchEventHandler(_ handler: MatchEventHandler, historyDidUpdate: [MatchEvent]) {
    onHistoryUpdate?(historyDidUpdate)
  }

  @MainActor
  func matchEventHandler(
    _ handler: MatchEventHandler,
    didUpdateWarnings warnings: [FrequentMatchWarning]
  ) {
    onWarningsUpdate?(warnings)
  }
}

extension LogMonitor: LogMonitoring {}

// MARK: - Alerts

@MainActor
private extension LogMonitor {
  func presentPatternLimitAlert(totalPatternCount: Int) {
    guard !didWarnAboutPatternLimit else { return }
    didWarnAboutPatternLimit = true
    let droppedCount = totalPatternCount - maxWatcherCount
    let patternWord = droppedCount == 1 ? "pattern was" : "patterns were"
    alertPresenter.presentAlert(
      title: "Pattern limit reached",
      message: """
      Simmer can monitor up to \(maxWatcherCount) patterns at a time. \(droppedCount) \(patternWord) \
      left inactive after the latest import. Remove or disable patterns in Settings to resume monitoring.
      """
    )
  }
}

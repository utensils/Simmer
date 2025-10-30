//
//  LogMonitorMatchProcessor.swift
//  Simmer
//
//  Handles background match aggregation for ``LogMonitor``.
//

import Foundation

internal struct LogMonitorMatchContext {
  let patternMatcher: PatternMatcherProtocol
  let stateStore: LogMonitorStateStore
  let animationTracker: LogMonitorAnimationTracker
  let dateProvider: () -> Date
  let onMatch: @MainActor (UUID, String, Int, String) -> Void
}

internal enum LogMonitorMatchProcessor {
  static func process(
    lines: [String],
    patternID: UUID,
    filePath: String,
    context: LogMonitorMatchContext
  ) {
    guard var watchContext = context.stateStore.context(for: patternID) else { return }
    var matches: [(line: String, number: Int)] = []

    for line in lines {
      watchContext.lineCount += 1
      if context.patternMatcher.match(line: line, pattern: watchContext.pattern) != nil {
        matches.append((line, watchContext.lineCount))
      }
    }

    context.stateStore.updateLineCount(for: patternID, to: watchContext.lineCount)
    guard !matches.isEmpty else { return }

    context.animationTracker.recordLatencyStart(
      for: patternID,
      matchCount: matches.count,
      timestamp: context.dateProvider()
    )

    Task { @MainActor in
      for match in matches {
        await context.onMatch(patternID, match.line, match.number, filePath)
      }
    }
  }
}

//
//  MatchEventHandler.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Aggregates match events, maintains bounded history, and notifies delegate callbacks.
@MainActor
final class MatchEventHandler: NSObject {
    weak var delegate: MatchEventHandlerDelegate?

    private(set) var history: [MatchEvent] = []
    private let maxHistoryCount: Int

    override init() {
        self.maxHistoryCount = 100
        super.init()
    }

    init(maxHistoryCount: Int = 100) {
        self.maxHistoryCount = maxHistoryCount
        super.init()
    }

    /// Records a new match event and notifies the delegate.
    /// - Parameters:
    ///   - pattern: The pattern that triggered the match.
    ///   - line: The log line content.
    ///   - lineNumber: The line number within the log file.
    ///   - filePath: The log file path (denormalized for display).
    func handleMatch(
        pattern: LogPattern,
        line: String,
        lineNumber: Int,
        filePath: String
    ) {
        let event = MatchEvent(
            patternID: pattern.id,
            patternName: pattern.name,
            matchedLine: line,
            lineNumber: lineNumber,
            filePath: filePath
        )

        append(event: event)
        delegate?.matchEventHandler(self, didDetectMatch: event)
        delegate?.matchEventHandler(self, historyDidUpdate: history)
    }

    /// Returns most recent matches, newest first, capped to the requested limit.
    func recentMatches(limit: Int = 10) -> [MatchEvent] {
        guard limit > 0 else { return [] }
        return history.suffix(limit).reversed()
    }

    /// Removes all stored match events and notifies delegate.
    func clearHistory() {
        guard !history.isEmpty else { return }
        history.removeAll()
        delegate?.matchEventHandler(self, historyDidUpdate: history)
    }

    private func append(event: MatchEvent) {
        history.append(event)
        if history.count > maxHistoryCount {
            history = Array(history.suffix(maxHistoryCount))
        }
    }
}

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
    private let warningThreshold = 50
    private var streaks: [UUID: Int] = [:]
    private var lastMatchedPatternID: UUID?
    private var warningsByPatternID: [UUID: FrequentMatchWarning] = [:]

    override init() {
        self.maxHistoryCount = 100
        super.init()
    }

    init(maxHistoryCount: Int = 100) {
        self.maxHistoryCount = maxHistoryCount
        super.init()
    }

    /// Current warnings raised for high-frequency matches.
    var activeWarnings: [FrequentMatchWarning] {
        warningsByPatternID.values.sorted { $0.triggeredAt < $1.triggeredAt }
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
        filePath: String,
        priority: Int = 0
    ) {
        let event = MatchEvent(
            patternID: pattern.id,
            patternName: pattern.name,
            matchedLine: line,
            lineNumber: lineNumber,
            filePath: filePath,
            priority: priority
        )

        append(event: event)
        delegate?.matchEventHandler(self, didDetectMatch: event)
        delegate?.matchEventHandler(self, historyDidUpdate: history)
        evaluateWarningThreshold(for: pattern)
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
        resetStreaks()
        if !warningsByPatternID.isEmpty {
            warningsByPatternID.removeAll()
            delegate?.matchEventHandler(self, didUpdateWarnings: activeWarnings)
        }
    }

    /// Dismisses an active warning and resets its streak counter.
    /// - Parameter patternID: Identifier for the pattern whose warning should be cleared.
    func acknowledgeWarning(for patternID: UUID) {
        guard warningsByPatternID.removeValue(forKey: patternID) != nil else { return }
        streaks[patternID] = 0
        if lastMatchedPatternID == patternID {
            lastMatchedPatternID = nil
        }
        delegate?.matchEventHandler(self, didUpdateWarnings: activeWarnings)
    }

    private func append(event: MatchEvent) {
        history.append(event)
        if history.count > maxHistoryCount {
            history = Array(history.suffix(maxHistoryCount))
        }
    }

    private func evaluateWarningThreshold(for pattern: LogPattern) {
        let streak = updateStreak(for: pattern.id)
        guard streak >= warningThreshold else { return }

    if warningsByPatternID[pattern.id] == nil {
            warningsByPatternID[pattern.id] = FrequentMatchWarning(
                patternID: pattern.id,
                patternName: pattern.name
            )
            delegate?.matchEventHandler(self, didUpdateWarnings: activeWarnings)
        }
    }

    private func updateStreak(for patternID: UUID) -> Int {
        defer { lastMatchedPatternID = patternID }

        if lastMatchedPatternID == patternID {
            let updated = (streaks[patternID] ?? 0) + 1
            streaks[patternID] = updated
            return updated
        } else {
            if let last = lastMatchedPatternID {
                streaks[last] = 0
            }
            streaks[patternID] = 1
            return 1
        }
    }

    private func resetStreaks() {
        streaks.removeAll()
        lastMatchedPatternID = nil
    }
}

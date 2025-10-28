//
//  MockPatternMatcher.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import Foundation
@testable import Simmer

/// Mock pattern matcher for testing without real NSRegularExpression
class MockPatternMatcher: PatternMatcherProtocol {
    private var configuredMatches: [(patternID: UUID, line: String, result: MatchResult)] = []

    func addMatch(for patternID: UUID, line: String, result: MatchResult) {
        configuredMatches.append((patternID, line, result))
    }

    func match(line: String, pattern: LogPattern) -> MatchResult? {
        configuredMatches.first { $0.patternID == pattern.id && $0.line == line }?.result
    }

    func reset() {
        configuredMatches.removeAll()
    }
}

//
//  PatternMatcherProtocol.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Contract for regex pattern matching
/// Per contracts/internal-protocols.md
protocol PatternMatcherProtocol {
    /// Evaluate line against pattern, returns MatchResult with range and captures
    func match(line: String, pattern: LogPattern) -> MatchResult?
}

struct MatchResult: Equatable {
    let range: NSRange
    let captureGroups: [String]
}

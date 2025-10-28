//
//  PatternMatcherProtocol.swift
//  Simmer
//
//  Abstraction over regex evaluation to aid in testing higher level flows.
//

import Foundation

struct MatchResult: Equatable {
  let range: NSRange
  let captureGroups: [String]
}

/// Defines a contract for evaluating log lines against persisted patterns.
protocol PatternMatcherProtocol {
  func match(line: String, pattern: LogPattern) -> MatchResult?
}

//
//  MockPatternMatcher.swift
//  SimmerTests
//
//  Predictable ``PatternMatcherProtocol`` implementation for unit tests.
//

import Foundation
@testable import Simmer

internal final class MockPatternMatcher: PatternMatcherProtocol {
  private var queuedResults: [UUID: [MatchResult?]] = [:]
  private(set) var evaluatedLines: [String] = []

  var fallbackResult: MatchResult?

  func match(line: String, pattern: LogPattern) -> MatchResult? {
    evaluatedLines.append(line)

    if var results = queuedResults[pattern.id], !results.isEmpty {
      let next = results.removeFirst()
      queuedResults[pattern.id] = results
      return next
    }

    return fallbackResult
  }

  func enqueue(_ result: MatchResult?, for patternID: UUID) {
    var results = queuedResults[patternID, default: []]
    results.append(result)
    queuedResults[patternID] = results
  }

  func clear() {
    queuedResults.removeAll()
    evaluatedLines.removeAll()
    fallbackResult = nil
  }
}

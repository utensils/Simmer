//
//  PatternMatcher.swift
//  Simmer
//
//  NSRegularExpression-backed implementation of ``PatternMatcherProtocol``.
//

import Foundation
import os

internal final class RegexPatternMatcher: PatternMatcherProtocol {
  // Cache retained for backwards compatibility, but prefer pattern.compiledRegex()
  private let cache: NSCache<NSString, NSRegularExpression> = {
    let cache = NSCache<NSString, NSRegularExpression>()
    cache.countLimit = 100 // Prevent unbounded growth
    return cache
  }()

  private let cacheQueue = DispatchQueue(
    label: "io.utensils.Simmer.regex-cache",
    attributes: .concurrent
  )
  private let logger = Logger(subsystem: "io.utensils.Simmer", category: "PatternMatcher")

  func match(line: String, pattern: LogPattern) -> MatchResult? {
    guard pattern.enabled else {
      return nil
    }

    // Use pre-compiled regex from LogPattern (T094 optimization)
    guard let expression = pattern.compiledRegex() ?? regex(for: pattern.regex) else {
      self.logger.warning(
        """
        Invalid regex for pattern '\(pattern.name, privacy: .public)'.
        Expression: '\(pattern.regex, privacy: .public)'
        """
      )
      return nil
    }

    let searchRange = NSRange(line.startIndex ..< line.endIndex, in: line)
    guard let result = expression.firstMatch(in: line, options: [], range: searchRange) else {
      return nil
    }

    var captures: [String] = []
    if result.numberOfRanges > 1 {
      for index in 1 ..< result.numberOfRanges {
        let nsRange = result.range(at: index)
        if let range = Range(nsRange, in: line) {
          captures.append(String(line[range]))
        } else {
          captures.append("")
        }
      }
    }

    return MatchResult(range: result.range, captureGroups: captures)
  }

  /// Exposed internally to support test coverage of the cache path.
  func regex(for pattern: String) -> NSRegularExpression? {
    let key = pattern as NSString

    var cached: NSRegularExpression?
    self.cacheQueue.sync {
      cached = self.cache.object(forKey: key)
    }

    if let existing = cached {
      return existing
    }

    do {
      let compiled = try NSRegularExpression(pattern: pattern, options: [])
      self.cacheQueue.sync(flags: .barrier) {
        self.cache.setObject(compiled, forKey: key)
      }
      return compiled
    } catch {
      self.logger.warning(
        """
        Failed to compile regex '\(pattern, privacy: .public)'.
        Error: \(error.localizedDescription, privacy: .public)
        """
      )
      return nil
    }
  }
}

//
//  PatternMatcher.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Production implementation of PatternMatcherProtocol using NSRegularExpression
class RegexPatternMatcher: PatternMatcherProtocol {
    private var compiledPatterns: [UUID: NSRegularExpression] = [:]

    func match(line: String, pattern: LogPattern) -> MatchResult? {
        // Get or compile regex for this pattern
        let regex: NSRegularExpression
        if let cached = compiledPatterns[pattern.id] {
            regex = cached
        } else {
            do {
                regex = try NSRegularExpression(pattern: pattern.regex, options: [])
                compiledPatterns[pattern.id] = regex
            } catch {
                print("Invalid regex pattern '\(pattern.regex)': \(error)")
                return nil
            }
        }

        // Match against line
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        // Extract capture groups
        var captureGroups: [String] = []
        for i in 0..<match.numberOfRanges {
            let matchRange = match.range(at: i)
            if matchRange.location != NSNotFound,
               let swiftRange = Range(matchRange, in: line) {
                captureGroups.append(String(line[swiftRange]))
            } else {
                captureGroups.append("")
            }
        }

        return MatchResult(range: match.range, captureGroups: captureGroups)
    }
}

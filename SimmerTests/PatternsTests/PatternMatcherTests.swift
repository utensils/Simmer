//
//  PatternMatcherTests.swift
//  SimmerTests
//

import XCTest
@testable import Simmer

internal final class PatternMatcherTests: XCTestCase {
  private var matcher: RegexPatternMatcher!

  override func setUp() {
    super.setUp()
    matcher = RegexPatternMatcher()
  }

  override func tearDown() {
    matcher = nil
    super.tearDown()
  }

  func test_match_whenPatternEnabledAndLineMatches_returnsResult() {
    let pattern = logPattern(regex: "ERROR: (.*)")
    let line = "ERROR: Something broke"

    let result = matcher.match(line: line, pattern: pattern)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.captureGroups.first, "Something broke")
    XCTAssertEqual(result?.range, NSRange(location: 0, length: line.count))
  }

  func test_match_whenPatternDisabled_returnsNil() {
    let pattern = logPattern(regex: "ERROR", enabled: false)

    XCTAssertNil(matcher.match(line: "ERROR", pattern: pattern))
  }

  func test_match_whenNoMatchOccurs_returnsNil() {
    let pattern = logPattern(regex: "WARN")

    XCTAssertNil(matcher.match(line: "INFO: Startup complete", pattern: pattern))
  }

  func test_match_whenRegexInvalid_returnsNil() {
    let pattern = logPattern(regex: "([A-Z") // Missing closing bracket

    XCTAssertNil(matcher.match(line: "ERROR", pattern: pattern))
  }

  func test_match_whenLineContainsSpecialCharacters_handlesEscapes() {
    let pattern = logPattern(regex: #"User\(id: (\d+)\)"#)
    let line = "User(id: 42) connected"

    let result = matcher.match(line: line, pattern: pattern)

    XCTAssertEqual(result?.captureGroups.first, "42")
  }

  func test_match_whenMultilinePatternUsed_matchesEachLine() {
    let pattern = logPattern(regex: #"(?m)^ERROR: (.*)$"#)
    let line = """
    INFO: ok
    ERROR: failed
    INFO: done
    """

    let result = matcher.match(line: line, pattern: pattern)

    XCTAssertEqual(result?.captureGroups.first, "failed")
  }

  func test_match_whenCalledMultipleTimes_reusesCompiledExpression() {
    let pattern = logPattern(regex: "ERROR")

    let first = matcher.match(line: "ERROR happened", pattern: pattern)
    let second = matcher.match(line: "ERROR again", pattern: pattern)

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
  }

  func test_match_whenCompiledRegexUnavailable_compilesAndCachesExpression() {
    let pattern = logPattern(regex: "INFO (\\d+)", precompile: false)

    let first = matcher.match(line: "INFO 99", pattern: pattern)
    XCTAssertEqual(first?.captureGroups.first, "99")

    // Change line to ensure cached expression is reused without recompile failure.
    let second = matcher.match(line: "INFO 123", pattern: pattern)
    XCTAssertEqual(second?.captureGroups.first, "123")
  }

  func test_match_whenCaptureGroupMissing_appendsEmptyString() {
    let pattern = logPattern(regex: #"ERROR:? (?:code: (\d+))?"#)
    let line = "ERROR without code"

    let result = matcher.match(line: line, pattern: pattern)

    XCTAssertEqual(result?.captureGroups.count, 1)
    XCTAssertEqual(result?.captureGroups.first, "")
  }

  // MARK: - Helpers

  private func logPattern(
    regex: String,
    enabled: Bool = true,
    name: String = "Test Pattern",
    filePath: String = "/tmp/test.log",
    precompile: Bool = true
  ) -> LogPattern {
    LogPattern(
      name: name,
      regex: regex,
      logPath: filePath,
      color: CodableColor(red: 1, green: 0, blue: 0),
      animationStyle: .glow,
      enabled: enabled,
      precompileRegex: precompile
    )
  }
}

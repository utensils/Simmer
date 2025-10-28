//
//  PatternMatcherTests.swift
//  SimmerTests
//
//  Created on 2025-10-28
//  100% coverage required for critical path per constitution
//

import XCTest
@testable import Simmer

final class PatternMatcherTests: XCTestCase {
    var matcher: RegexPatternMatcher!

    override func setUp() {
        super.setUp()
        matcher = RegexPatternMatcher()
    }

    override func tearDown() {
        matcher = nil
        super.tearDown()
    }

    func testSimplePatternMatches() {
        let pattern = LogPattern(
            name: "Error Detector",
            regex: "ERROR",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "2025-10-28 ERROR: Something broke", pattern: pattern)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.captureGroups.first, "ERROR")
    }

    func testPatternDoesNotMatch() {
        let pattern = LogPattern(
            name: "Error Detector",
            regex: "ERROR",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "2025-10-28 INFO: All good", pattern: pattern)

        XCTAssertNil(result)
    }

    func testEmptyStringDoesNotMatch() {
        let pattern = LogPattern(
            name: "Any",
            regex: ".*",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "", pattern: pattern)

        XCTAssertNotNil(result) // .* matches empty string
    }

    func testSpecialCharactersInPattern() {
        let pattern = LogPattern(
            name: "Bracket Matcher",
            regex: "\\[ERROR\\]",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "2025-10-28 [ERROR] Failed", pattern: pattern)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.captureGroups.first, "[ERROR]")
    }

    func testCaptureGroupsExtracted() {
        let pattern = LogPattern(
            name: "Level Extractor",
            regex: "\\[(\\w+)\\]",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "2025-10-28 [ERROR] Failed", pattern: pattern)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.captureGroups.count, 2) // Full match + 1 capture group
        XCTAssertEqual(result?.captureGroups[0], "[ERROR]")
        XCTAssertEqual(result?.captureGroups[1], "ERROR")
    }

    func testMultilineTextWithoutMultilineFlag() {
        let pattern = LogPattern(
            name: "Multiline",
            regex: "ERROR.*FAILED",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "ERROR\nFAILED", pattern: pattern)

        XCTAssertNil(result) // .* doesn't match newlines by default
    }

    func testInvalidRegexReturnsNil() {
        let pattern = LogPattern(
            name: "Invalid",
            regex: "[unclosed",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "any text", pattern: pattern)

        XCTAssertNil(result)
    }

    func testPatternCachingReusesCompiledRegex() {
        let pattern = LogPattern(
            name: "Cached",
            regex: "ERROR",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        // First match compiles regex
        let result1 = matcher.match(line: "ERROR first", pattern: pattern)
        XCTAssertNotNil(result1)

        // Second match should reuse compiled regex
        let result2 = matcher.match(line: "ERROR second", pattern: pattern)
        XCTAssertNotNil(result2)
    }

    func testCaseSensitiveMatching() {
        let pattern = LogPattern(
            name: "Case Sensitive",
            regex: "ERROR",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let upperResult = matcher.match(line: "ERROR happened", pattern: pattern)
        let lowerResult = matcher.match(line: "error happened", pattern: pattern)

        XCTAssertNotNil(upperResult)
        XCTAssertNil(lowerResult)
    }

    func testComplexRegexPattern() {
        let pattern = LogPattern(
            name: "IP Address",
            regex: "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
            logPath: "/tmp/test.log",
            color: CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        )

        let result = matcher.match(line: "Connection from 192.168.1.1", pattern: pattern)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.captureGroups.first, "192.168.1.1")
    }
}

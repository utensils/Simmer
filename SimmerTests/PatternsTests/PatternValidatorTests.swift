import XCTest
@testable import Simmer

internal final class PatternValidatorTests: XCTestCase {
    // MARK: - Valid Patterns

    func testValidPattern_SimpleText() {
        let result = PatternValidator.validate("error")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithWildcard() {
        let result = PatternValidator.validate("error.*")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithCharacterClass() {
        let result = PatternValidator.validate("[0-9]+")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithGroups() {
        let result = PatternValidator.validate("(error|warning)")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithQuantifiers() {
        let result = PatternValidator.validate("a+b*c?d{2,3}")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithEscapedCharacters() {
        let result = PatternValidator.validate("\\d+\\.\\d+")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithWordBoundaries() {
        let result = PatternValidator.validate("\\berror\\b")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_WithAnchors() {
        let result = PatternValidator.validate("^ERROR.*$")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testValidPattern_ComplexLogPattern() {
        let result = PatternValidator.validate("\\[\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\]\\s(ERROR|WARN)")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }

    func testIsValid_ReturnsTrue_ForValidPattern() {
        XCTAssertTrue(PatternValidator.isValid("error"))
        XCTAssertTrue(PatternValidator.isValid("\\d+"))
        XCTAssertTrue(PatternValidator.isValid("[a-z]+"))
    }

    // MARK: - Invalid Patterns

    func testInvalidPattern_Empty() {
        let result = PatternValidator.validate("")
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Pattern cannot be empty")
    }

    func testInvalidPattern_UnmatchedOpenParenthesis() {
        let result = PatternValidator.validate("(error")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        // Error message should indicate the problem, exact wording may vary
    }

    func testInvalidPattern_UnmatchedCloseParenthesis() {
        let result = PatternValidator.validate("error)")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testInvalidPattern_UnmatchedOpenBracket() {
        let result = PatternValidator.validate("[a-z")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testInvalidPattern_TrailingBackslash() {
        let result = PatternValidator.validate("error\\")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("backslash") ?? false)
    }

    func testInvalidPattern_InvalidEscapeSequence() {
        let result = PatternValidator.validate("\\k")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testInvalidPattern_NothingToRepeat() {
        let result = PatternValidator.validate("*error")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("repeat") ?? false)
    }

    func testInvalidPattern_InvalidQuantifier() {
        let result = PatternValidator.validate("a{")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testInvalidPattern_InvalidRange() {
        let result = PatternValidator.validate("[z-a]")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }

    func testIsValid_ReturnsFalse_ForInvalidPattern() {
        XCTAssertFalse(PatternValidator.isValid(""))
        XCTAssertFalse(PatternValidator.isValid("(unclosed"))
        XCTAssertFalse(PatternValidator.isValid("*invalid"))
    }

    // MARK: - Special Characters

    func testValidPattern_SpecialCharactersEscaped() {
        let specialChars = ["\\.", "\\^", "\\$", "\\*", "\\+", "\\?", "\\(", "\\)", "\\[", "\\]", "\\{", "\\}"]
        for pattern in specialChars {
            let result = PatternValidator.validate(pattern)
            XCTAssertTrue(result.isValid, "Pattern \(pattern) should be valid")
        }
    }

    func testValidPattern_PipeCharacter() {
        let result = PatternValidator.validate("error|warning")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_BackslashInCharacterClass() {
        let result = PatternValidator.validate("[\\\\]")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Edge Cases

    func testValidPattern_SingleCharacter() {
        let result = PatternValidator.validate("a")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_OnlyDot() {
        let result = PatternValidator.validate(".")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_OnlyCaret() {
        let result = PatternValidator.validate("^")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_OnlyDollar() {
        let result = PatternValidator.validate("$")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_EmptyAlternation() {
        let result = PatternValidator.validate("a||b")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_NestedGroups() {
        let result = PatternValidator.validate("((a)(b))")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_NonCapturingGroup() {
        let result = PatternValidator.validate("(?:error)")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_Lookahead() {
        let result = PatternValidator.validate("error(?=:)")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_LongPattern() {
        let longPattern = String(repeating: "a", count: 1000)
        let result = PatternValidator.validate(longPattern)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Real-World Log Patterns

    func testValidPattern_ISO8601Timestamp() {
        let result = PatternValidator.validate("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_IPAddress() {
        let result = PatternValidator.validate("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_EmailAddress() {
        let result = PatternValidator.validate("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_HTTPStatusCode() {
        let result = PatternValidator.validate("HTTP/\\d\\.\\d\\s[45]\\d{2}")
        XCTAssertTrue(result.isValid)
    }

    func testValidPattern_StackTrace() {
        let result = PatternValidator.validate("at\\s[\\w.]+\\([\\w.]+:\\d+\\)")
        XCTAssertTrue(result.isValid)
    }
}

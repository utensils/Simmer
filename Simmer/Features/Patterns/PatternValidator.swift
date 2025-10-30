import Foundation

/// Validates regex patterns for syntax correctness
internal struct PatternValidator {
    /// Validation result for a regex pattern
    internal enum ValidationResult {
        case valid

        case invalid(error: String)

        var isValid: Bool {
            if case .valid = self {
                return true
            }
            return false
        }

        var errorMessage: String? {
            if case .invalid(let error) = self {
                return error
            }
            return nil
        }
    }

    /// Validates a regex pattern string
    /// - Parameter pattern: The regex pattern to validate
    /// - Returns: ValidationResult indicating valid or error status
    static func validate(_ pattern: String) -> ValidationResult {
        // Empty patterns are invalid
        guard !pattern.isEmpty else {
            return .invalid(error: "Pattern cannot be empty")
        }

        // Attempt to compile the regex
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return .valid
        } catch let error as NSError {
            // Extract meaningful error message from NSError
            let errorMessage = extractErrorMessage(from: error, pattern: pattern)
            return .invalid(error: errorMessage)
        }
    }

    /// Validates a regex pattern and returns a boolean result
    /// - Parameter pattern: The regex pattern to validate
    /// - Returns: true if pattern is valid, false otherwise
    static func isValid(_ pattern: String) -> Bool {
        return validate(pattern).isValid
    }

    // MARK: - Private Helpers

    private static func extractErrorMessage(
      from error: NSError,
      pattern: String
    ) -> String {
      if pattern.hasSuffix("\\") {
        return "Invalid escape sequence (trailing backslash)"
      }

      if let first = pattern.first, "*+?".contains(first) {
        return "Quantifier (*, +, ?, {}) has nothing to repeat"
      }

      // NSRegularExpression errors are in the NSCocoaErrorDomain
      // The localized description usually contains useful info
      let description = error.localizedDescription

      // Clean up common error patterns for better UX
      if description.contains("unmatched") {
        return "Unmatched parenthesis or bracket"
      } else if description.contains("trailing backslash") {
        return "Invalid escape sequence (trailing backslash)"
      } else if description.contains("invalid") {
        return "Invalid regex syntax"
      } else if description.contains("nothing to repeat") {
        return "Quantifier (*,+,?,{}) has nothing to repeat"
      } else if description.contains("unrecognized character") {
        return "Unrecognized escape sequence"
      }

      // Return original description if no specific pattern matched
      return description
    }
}

import Foundation

/// Expands file paths by resolving tilde (~) and environment variables.
internal struct PathExpander {
    /// Expands a file path by resolving tilde and environment variables.
    /// Supports case-insensitive environment variable lookup to align with user expectations.
    /// - Parameter path: The path to expand (e.g., "~/logs/app.log" or "$HOME/logs/app.log")
    /// - Returns: The expanded path (e.g., "/Users/username/logs/app.log")
    static func expand(_ path: String) -> String {
        var expandedPath = path

        // Expand tilde (~) to home directory
        if expandedPath.hasPrefix("~") {
            let homeDirectory = NSHomeDirectory()
            if expandedPath == "~" {
                expandedPath = homeDirectory
            } else if expandedPath.hasPrefix("~/") {
                expandedPath = homeDirectory + expandedPath.dropFirst(1)
            }
        }

        // Expand environment variables (e.g., $HOME, $USER, ${VAR})
        expandedPath = expandEnvironmentVariables(in: expandedPath)

        return expandedPath
    }

    // MARK: - Private Helpers

    /// Expands environment variables in a string with case-insensitive matching.
    ///
    /// Supports both `$VAR` and `${VAR}` syntax. Environment variable names are matched
    /// case-insensitively, meaning `$home`, `$HOME`, and `$HoMe` all resolve to the same value.
    ///
    /// - Parameter string: The string containing environment variables to expand
    /// - Returns: The string with all environment variables replaced by their values
    private static func expandEnvironmentVariables(in string: String) -> String {
        var result = string
        let environment = ProcessInfo.processInfo.environment

        // Pattern 1: ${VAR} syntax (braced)
        let bracedPattern = "\\$\\{([A-Za-z_][A-Za-z0-9_]*)\\}"
        if let regex = try? NSRegularExpression(pattern: bracedPattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))

            // Process matches in reverse order to avoid index shifting
            for match in matches.reversed() {
                guard match.numberOfRanges == 2,
                      let matchRange = Range(match.range, in: result),
                      let varRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let varName = String(result[varRange])
                if let value = lookupEnvironmentValue(for: varName, environment: environment) {
                    result.replaceSubrange(matchRange, with: value)
                }
            }
        }

        // Pattern 2: $VAR syntax (unbraced)
        // Must be followed by non-alphanumeric character or end of string
        let unbracedPattern = "\\$([A-Za-z_][A-Za-z0-9_]*)(?=[^A-Za-z0-9_]|$)"
        if let regex = try? NSRegularExpression(pattern: unbracedPattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))

            // Process matches in reverse order to avoid index shifting
            for match in matches.reversed() {
                guard match.numberOfRanges == 2,
                      let matchRange = Range(match.range, in: result),
                      let varRange = Range(match.range(at: 1), in: result) else {
                    continue
                }

                let varName = String(result[varRange])
                if let value = lookupEnvironmentValue(for: varName, environment: environment) {
                    // Replace the entire match (including the $)
                    let startIndex = result.index(matchRange.lowerBound, offsetBy: 0)
                    let endIndex = result.index(matchRange.lowerBound, offsetBy: varName.count + 1)
                    let fullRange = startIndex..<endIndex
                    result.replaceSubrange(fullRange, with: value)
                }
            }
        }

        return result
    }

    /// Looks up an environment variable value with case-insensitive matching.
    ///
    /// First attempts an exact case-sensitive match, then falls back to case-insensitive
    /// comparison if no exact match is found. This allows `$home`, `$HOME`, and `$HoMe`
    /// to all resolve to the same environment variable value.
    ///
    /// - Parameters:
    ///   - variable: The environment variable name to look up
    ///   - environment: The environment dictionary to search
    /// - Returns: The environment variable value if found, nil otherwise
    private static func lookupEnvironmentValue(
        for variable: String,
        environment: [String: String]
    ) -> String? {
        if let exactMatch = environment[variable] {
            return exactMatch
        }
        if let caseInsensitiveKey = environment.keys.first(
            where: { $0.caseInsensitiveCompare(variable) == .orderedSame }
        ) {
            return environment[caseInsensitiveKey]
        }
        return nil
    }
}

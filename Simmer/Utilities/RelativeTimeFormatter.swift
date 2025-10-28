import Foundation

/// Formats timestamps as relative time strings (e.g., "2m ago", "1h ago")
struct RelativeTimeFormatter {
    /// Formats a date as a relative time string from now
    /// - Parameter date: The date to format
    /// - Returns: A string like "2m ago", "1h ago", "3d ago"
    static func string(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Handle future dates
        guard interval >= 0 else {
            return "just now"
        }

        // Seconds (< 60 seconds)
        if interval < 60 {
            let seconds = Int(interval)
            return seconds <= 1 ? "just now" : "\(seconds)s ago"
        }

        // Minutes (< 60 minutes)
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }

        // Hours (< 24 hours)
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }

        // Days
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }

    /// Formats a date as a relative time string from a specific reference date
    /// - Parameters:
    ///   - date: The date to format
    ///   - referenceDate: The reference date to compare against
    /// - Returns: A string like "2m ago", "1h ago", "3d ago"
    static func string(from date: Date, relativeTo referenceDate: Date) -> String {
        let interval = referenceDate.timeIntervalSince(date)

        // Handle future dates
        guard interval >= 0 else {
            return "just now"
        }

        // Seconds (< 60 seconds)
        if interval < 60 {
            let seconds = Int(interval)
            return seconds <= 1 ? "just now" : "\(seconds)s ago"
        }

        // Minutes (< 60 minutes)
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }

        // Hours (< 24 hours)
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }

        // Days
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

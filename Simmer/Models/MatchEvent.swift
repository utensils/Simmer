//
//  MatchEvent.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Represents a detected pattern match occurrence with metadata for display
/// Per data-model.md: In-memory only, not persisted, max 200 chars line content
struct MatchEvent: Identifiable, Equatable {
    let id: UUID
    let patternID: UUID
    let patternName: String
    let timestamp: Date
    let matchedLine: String
    let lineNumber: Int
    let filePath: String

    init(
        id: UUID = UUID(),
        patternID: UUID,
        patternName: String,
        timestamp: Date = Date(),
        matchedLine: String,
        lineNumber: Int,
        filePath: String
    ) {
        self.id = id
        self.patternID = patternID
        self.patternName = patternName
        self.timestamp = timestamp
        // Truncate matched line to 200 chars per data-model.md
        if matchedLine.count > 200 {
            let index = matchedLine.index(matchedLine.startIndex, offsetBy: 197)
            self.matchedLine = String(matchedLine[..<index]) + "..."
        } else {
            self.matchedLine = matchedLine
        }
        self.lineNumber = lineNumber
        self.filePath = filePath
    }
}

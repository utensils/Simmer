//
//  ConfigurationStoreProtocol.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Abstract persistence layer for pattern configurations
/// Per contracts/internal-protocols.md
protocol ConfigurationStoreProtocol {
    /// Load all patterns from storage
    func loadPatterns() -> [LogPattern]

    /// Save patterns to storage, throws on encoding/write errors
    func savePatterns(_ patterns: [LogPattern]) throws

    /// Delete specific pattern by ID
    func deletePattern(id: UUID) throws

    /// Update existing pattern
    func updatePattern(_ pattern: LogPattern) throws
}

enum ConfigurationStoreError: Error {
    case encodingFailed
    case decodingFailed
    case patternNotFound(UUID)
    case saveFailed
}

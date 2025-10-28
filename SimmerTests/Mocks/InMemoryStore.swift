//
//  InMemoryStore.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import Foundation
@testable import Simmer

/// In-memory implementation of ConfigurationStoreProtocol for testing
class InMemoryStore: ConfigurationStoreProtocol {
    private var patterns: [LogPattern] = []

    func loadPatterns() -> [LogPattern] {
        patterns
    }

    func savePatterns(_ patterns: [LogPattern]) throws {
        self.patterns = patterns
    }

    func deletePattern(id: UUID) throws {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else {
            throw ConfigurationStoreError.patternNotFound(id)
        }
        patterns.remove(at: index)
    }

    func updatePattern(_ pattern: LogPattern) throws {
        guard let index = patterns.firstIndex(where: { $0.id == pattern.id }) else {
            throw ConfigurationStoreError.patternNotFound(pattern.id)
        }
        patterns[index] = pattern
    }
}

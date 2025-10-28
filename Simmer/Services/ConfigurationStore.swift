//
//  ConfigurationStore.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// UserDefaults-backed implementation of ConfigurationStoreProtocol
/// Per plan.md: Patterns stored as JSON in UserDefaults under "patterns" key
class UserDefaultsStore: ConfigurationStoreProtocol {
    private let userDefaults: UserDefaults
    private let patternsKey = "patterns"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadPatterns() -> [LogPattern] {
        guard let data = userDefaults.data(forKey: patternsKey) else {
            return []
        }

        do {
            let patterns = try JSONDecoder().decode([LogPattern].self, from: data)
            return patterns
        } catch {
            print("Failed to decode patterns: \(error)")
            return []
        }
    }

    func savePatterns(_ patterns: [LogPattern]) throws {
        do {
            let data = try JSONEncoder().encode(patterns)
            userDefaults.set(data, forKey: patternsKey)
        } catch {
            throw ConfigurationStoreError.encodingFailed
        }
    }

    func deletePattern(id: UUID) throws {
        var patterns = loadPatterns()
        guard let index = patterns.firstIndex(where: { $0.id == id }) else {
            throw ConfigurationStoreError.patternNotFound(id)
        }

        patterns.remove(at: index)
        try savePatterns(patterns)
    }

    func updatePattern(_ pattern: LogPattern) throws {
        var patterns = loadPatterns()
        guard let index = patterns.firstIndex(where: { $0.id == pattern.id }) else {
            throw ConfigurationStoreError.patternNotFound(pattern.id)
        }

        patterns[index] = pattern
        try savePatterns(patterns)
    }
}

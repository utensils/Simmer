//
//  MatchEventHandlerDelegate.swift
//  Simmer
//
//  Created on 2025-10-28
//

import Foundation

/// Callback protocol for MatchEventHandler to notify consumers of new matches
/// and history updates.
internal protocol MatchEventHandlerDelegate: AnyObject {
    /// Called when a pattern match is detected and prioritized for animation.
    func matchEventHandler(
        _ handler: MatchEventHandler,
        didDetectMatch event: MatchEvent
    )

    /// Called whenever the match history array changes.
    func matchEventHandler(
        _ handler: MatchEventHandler,
        historyDidUpdate: [MatchEvent]
    )

    /// Called when high-frequency match warnings change.
    func matchEventHandler(
        _ handler: MatchEventHandler,
        didUpdateWarnings warnings: [FrequentMatchWarning]
    )
}

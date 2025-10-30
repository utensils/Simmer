//
//  LogMonitorAnimationTracker.swift
//  Simmer
//
//  Tracks animation throttling and latency timing for ``LogMonitor``.
//

import Foundation

internal final class LogMonitorAnimationTracker {
  private let queue: DispatchQueue
  private var lastAnimationTimestamps: [UUID: Date] = [:]
  private var currentAnimation: (patternID: UUID, priority: Int)?
  private var pendingLatencyStartDates: [UUID: [Date]] = [:]

  init(queueLabel: String) {
    self.queue = DispatchQueue(label: queueLabel)
  }

  func reset() {
    queue.sync {
      lastAnimationTimestamps.removeAll()
      currentAnimation = nil
      pendingLatencyStartDates.removeAll()
    }
  }

  func shouldTriggerAnimation(
    for patternID: UUID,
    priority: Int,
    timestamp: Date,
    isIconIdle: Bool,
    debounceInterval: TimeInterval
  ) -> Bool {
    queue.sync {
      if isIconIdle {
        currentAnimation = nil
      }

      if let last = lastAnimationTimestamps[patternID],
         timestamp.timeIntervalSince(last) < debounceInterval {
        return false
      }

      guard let current = currentAnimation else {
        return true
      }

      if priority < current.priority {
        return true
      }

      if current.patternID == patternID {
        return true
      }

      return isIconIdle
    }
  }

  func recordAnimationStart(for patternID: UUID, priority: Int, timestamp: Date) {
    queue.sync {
      currentAnimation = (patternID: patternID, priority: priority)
      lastAnimationTimestamps[patternID] = timestamp
    }
  }

  func recordLatencyStart(for patternID: UUID, matchCount: Int, timestamp: Date) {
    queue.sync {
      var queue = pendingLatencyStartDates[patternID] ?? []
      for _ in 0 ..< matchCount {
        queue.append(timestamp)
      }
      pendingLatencyStartDates[patternID] = queue
    }
  }

  func dequeueLatencyStart(for patternID: UUID) -> Date? {
    queue.sync {
      guard var queue = pendingLatencyStartDates[patternID], !queue.isEmpty else {
        return nil
      }
      let start = queue.removeFirst()
      pendingLatencyStartDates[patternID] = queue.isEmpty ? nil : queue
      return start
    }
  }
}

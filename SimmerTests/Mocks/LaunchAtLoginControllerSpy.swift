//
//  LaunchAtLoginControllerSpy.swift
//  SimmerTests
//

import Foundation
@testable import Simmer

final class LaunchAtLoginControllerSpy: LaunchAtLoginControlling {
  var isAvailable: Bool
  private(set) var storedPreference: Bool
  private(set) var setEnabledCalls: [Bool] = []
  private(set) var resolvedPreferenceCalls = 0
  var errorToThrow: Error?
  var resolvedPreferenceOverride: Bool?

  init(isAvailable: Bool = true, storedPreference: Bool = false) {
    self.isAvailable = isAvailable
    self.storedPreference = storedPreference
  }

  func resolvedPreference() -> Bool {
    resolvedPreferenceCalls += 1
    if let override = resolvedPreferenceOverride {
      storedPreference = override
      return override
    }
    return storedPreference
  }

  func setEnabled(_ enabled: Bool) throws {
    setEnabledCalls.append(enabled)
    if let errorToThrow {
      throw errorToThrow
    }
    storedPreference = enabled
  }
}

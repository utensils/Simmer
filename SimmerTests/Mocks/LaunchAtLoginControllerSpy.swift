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
  var errorToThrow: Error?

  init(isAvailable: Bool = true, storedPreference: Bool = false) {
    self.isAvailable = isAvailable
    self.storedPreference = storedPreference
  }

  func resolvedPreference() -> Bool {
    storedPreference
  }

  func setEnabled(_ enabled: Bool) throws {
    setEnabledCalls.append(enabled)
    if let errorToThrow {
      throw errorToThrow
    }
    storedPreference = enabled
  }
}

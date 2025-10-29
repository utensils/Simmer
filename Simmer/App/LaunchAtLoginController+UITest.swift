//
//  LaunchAtLoginController+UITest.swift
//  Simmer
//
//  Provides a lightweight stub for UI testing so we never mutate the real
//  Launch at Login registration while exercising the settings toggle.
//

import Foundation

/// Stubbed controller used when UI tests request Launch at Login isolation.
final class UITestLaunchAtLoginController: LaunchAtLoginControlling {
  private enum EnvironmentKeys {
    static let availability = "SIMMER_UI_TEST_LAUNCH_AT_LOGIN_AVAILABLE"
    static let initialState = "SIMMER_UI_TEST_LAUNCH_AT_LOGIN_INITIAL"
  }

  private(set) var isAvailable: Bool
  private var enabled: Bool

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    if let availability = environment[EnvironmentKeys.availability] {
      isAvailable = availability != "0"
    } else {
      isAvailable = true
    }
    let initial = environment[EnvironmentKeys.initialState] == "1"
    enabled = initial
  }

  func resolvedPreference() -> Bool {
    guard isAvailable else { return false }
    return enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    guard isAvailable else { throw LaunchAtLoginError.notSupported }
    self.enabled = enabled
  }
}

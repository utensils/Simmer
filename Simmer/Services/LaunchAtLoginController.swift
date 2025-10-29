//
//  LaunchAtLoginController.swift
//  Simmer
//
//  Manages macOS launch-at-login registration via SMAppService.
//

import Foundation
import os.log
import ServiceManagement

/// Errors that can occur while configuring launch at login support.
enum LaunchAtLoginError: LocalizedError, Equatable {
  case notSupported
  case operationFailed(message: String)

  var errorDescription: String? {
    switch self {
    case .notSupported:
      return "Launch at Login requires macOS 13 or newer."
    case .operationFailed(let message):
      return """
      Simmer couldn't update the Launch at Login setting: \(message)
      """
    }
  }
}

/// Abstraction for enabling or disabling Launch at Login.
protocol LaunchAtLoginControlling: AnyObject {
  /// Whether Launch at Login can be configured on the current OS.
  var isAvailable: Bool { get }

  /// Returns the effective preference after reconciling with SMAppService state.
  func resolvedPreference() -> Bool

  /// Updates Launch at Login configuration and persists the preference.
  func setEnabled(_ enabled: Bool) throws
}

/// Default implementation that persists the preference in `UserDefaults`
/// and calls through to `SMAppService` on macOS 13+.
final class LaunchAtLoginController: LaunchAtLoginControlling {
  private enum Constants {
    static let preferenceKey = "launchAtLoginEnabled"
    static let logger = OSLog(subsystem: "io.utensils.Simmer", category: "LaunchAtLogin")
  }

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  var isAvailable: Bool {
    if #available(macOS 13, *) {
      return true
    }
    return false
  }

  func resolvedPreference() -> Bool {
    guard isAvailable else {
      return false
    }

    guard #available(macOS 13, *) else {
      return false
    }

    let service = SMAppService.mainApp
    switch service.status {
    case .enabled:
      userDefaults.set(true, forKey: Constants.preferenceKey)
      return true
    case .notRegistered:
      userDefaults.set(false, forKey: Constants.preferenceKey)
      return false
    case .requiresApproval:
      return userDefaults.bool(forKey: Constants.preferenceKey)
    @unknown default:
      os_log(
        "Encountered unknown SMAppService status: %{public}@",
        log: Constants.logger,
        type: .error,
        String(describing: service.status)
      )
      return userDefaults.bool(forKey: Constants.preferenceKey)
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    guard isAvailable else {
      throw LaunchAtLoginError.notSupported
    }

    guard #available(macOS 13, *) else {
      throw LaunchAtLoginError.notSupported
    }

    let service = SMAppService.mainApp
    do {
      switch (enabled, service.status) {
      case (true, .enabled):
        userDefaults.set(true, forKey: Constants.preferenceKey)
      case (true, _):
        try service.register()
        userDefaults.set(true, forKey: Constants.preferenceKey)
        os_log("Launch at Login enabled", log: Constants.logger, type: .info)
      case (false, .enabled):
        try service.unregister()
        fallthrough
      case (false, _):
        userDefaults.set(false, forKey: Constants.preferenceKey)
        os_log("Launch at Login disabled", log: Constants.logger, type: .info)
      }
    } catch {
      os_log(
        "Failed to update Launch at Login: %{public}@",
        log: Constants.logger,
        type: .error,
        String(describing: error)
      )
      throw LaunchAtLoginError.operationFailed(message: error.localizedDescription)
    }
  }
}

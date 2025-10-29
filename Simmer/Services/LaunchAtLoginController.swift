//
//  LaunchAtLoginController.swift
//  Simmer
//
//  Manages macOS launch-at-login registration via SMAppService.
//

import Foundation
import os.log
import ServiceManagement

/// Internal representation of the launch agent status returned by `SMAppService`.
internal enum LaunchAtLoginServiceStatus: Equatable {
  case enabled
  case notRegistered
  case requiresApproval
  case unknown(String)
}

/// Abstraction over `SMAppService` so tests can inject fakes without touching system state.
internal protocol LaunchAtLoginService {
  var status: LaunchAtLoginServiceStatus { get }
  func register() throws
  func unregister() throws
}

/// Adapter that bridges `SMAppService` to `LaunchAtLoginService`.
@available(macOS 13, *)
internal final class SMAppServiceAdapter: LaunchAtLoginService {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  var status: LaunchAtLoginServiceStatus {
    switch service.status {
    case .enabled:
      return .enabled
    case .notRegistered:
      return .notRegistered
    case .requiresApproval:
      return .requiresApproval
    @unknown default:
      return .unknown(String(describing: service.status))
    }
  }

  func register() throws {
    try service.register()
  }

  func unregister() throws {
    try service.unregister()
  }
}

/// Errors that can occur while configuring launch at login support.
internal enum LaunchAtLoginError: LocalizedError, Equatable {
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
internal protocol LaunchAtLoginControlling: AnyObject {
  /// Whether Launch at Login can be configured on the current OS.
  var isAvailable: Bool { get }

  /// Returns the effective preference after reconciling with SMAppService state.
  func resolvedPreference() -> Bool

  /// Updates Launch at Login configuration and persists the preference.
  func setEnabled(_ enabled: Bool) throws
}

/// Default implementation that persists the preference in `UserDefaults`
/// and calls through to `SMAppService` on macOS 13+.
internal final class LaunchAtLoginController: LaunchAtLoginControlling {
  private enum Constants {
    static let preferenceKey = "launchAtLoginEnabled"
    static let logger = OSLog(subsystem: "io.utensils.Simmer", category: "LaunchAtLogin")
  }

  private let userDefaults: UserDefaults
  private let serviceProvider: () -> LaunchAtLoginService?

  init(
    userDefaults: UserDefaults = .standard,
    serviceProvider: @escaping () -> LaunchAtLoginService? = {
      guard #available(macOS 13, *) else { return nil }
      return SMAppServiceAdapter()
    }
  ) {
    self.userDefaults = userDefaults
    self.serviceProvider = serviceProvider
  }

  var isAvailable: Bool {
    makeService() != nil
  }

  func resolvedPreference() -> Bool {
    guard let service = makeService() else {
      return false
    }

    switch service.status {
    case .enabled:
      userDefaults.set(true, forKey: Constants.preferenceKey)
      return true
    case .notRegistered:
      userDefaults.set(false, forKey: Constants.preferenceKey)
      return false
    case .requiresApproval:
      return userDefaults.bool(forKey: Constants.preferenceKey)
    case .unknown(let description):
      os_log(
        "Encountered unknown Launch at Login status: %{public}@",
        log: Constants.logger,
        type: .error,
        description
      )
      return userDefaults.bool(forKey: Constants.preferenceKey)
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    guard let service = makeService() else {
      throw LaunchAtLoginError.notSupported
    }

    do {
      switch (enabled, service.status) {
      case (true, .enabled):
        userDefaults.set(true, forKey: Constants.preferenceKey)
      case (true, .notRegistered), (true, .requiresApproval), (true, .unknown):
        try service.register()
        userDefaults.set(true, forKey: Constants.preferenceKey)
        os_log("Launch at Login enabled", log: Constants.logger, type: .info)
      case (false, .enabled):
        try service.unregister()
        userDefaults.set(false, forKey: Constants.preferenceKey)
        os_log("Launch at Login disabled", log: Constants.logger, type: .info)
      case (false, .notRegistered), (false, .requiresApproval), (false, .unknown):
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

  // MARK: - Helpers

  private func makeService() -> LaunchAtLoginService? {
    guard #available(macOS 13, *) else {
      return nil
    }
    return serviceProvider()
  }
}

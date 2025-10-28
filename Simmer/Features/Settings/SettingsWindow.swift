//
//  SettingsWindow.swift
//  Simmer
//
//  SwiftUI WindowGroup coordinator for pattern configuration UI.
//

import SwiftUI

/// Creates and manages the settings window displaying pattern configuration.
struct SettingsWindow: Scene {
  var body: some Scene {
    WindowGroup("Simmer Settings") {
      PatternListView()
        .frame(minWidth: 600, minHeight: 400)
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 700, height: 500)
  }
}

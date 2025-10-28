//
//  SimmerApp.swift
//  Simmer
//
//  Created by James Brink on 10/28/25.
//

import SwiftUI

@main
struct SimmerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

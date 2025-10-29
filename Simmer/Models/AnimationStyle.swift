//
//  AnimationStyle.swift
//  Simmer
//
//  Defines available icon animation styles declared in the MVP data model.
//

import Foundation

/// Menu bar icon animation styles supported by Simmer.
internal enum AnimationStyle: String, Codable, CaseIterable {
  case glow = "glow"
  case pulse = "pulse"
  case blink = "blink"
}

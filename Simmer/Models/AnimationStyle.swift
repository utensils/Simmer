//
//  AnimationStyle.swift
//  Simmer
//
//  Defines available icon animation styles declared in the MVP data model.
//

import Foundation

/// Menu bar icon animation styles supported by Simmer.
enum AnimationStyle: String, Codable, CaseIterable {
  case glow
  case pulse
  case blink
}

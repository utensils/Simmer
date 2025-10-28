//
//  IconAnimatorDelegate.swift
//  Simmer
//
//  Delegate callbacks for menu bar icon animation lifecycle events.
//

import AppKit

protocol IconAnimatorDelegate: AnyObject {
  func animationDidStart(style: AnimationStyle, color: CodableColor)
  func animationDidEnd()
  func updateIcon(_ image: NSImage)
}

import AppKit
import Carbon.HIToolbox
import SwiftUI

enum LauncherKeyboardNavigation {
  private static let conflictingModifiers: NSEvent.ModifierFlags = [
    .command,
    .control,
    .option,
    .shift,
  ]

  static func hasOnlyCommandModifier(_ modifiers: NSEvent.ModifierFlags) -> Bool {
    modifiers.intersection(conflictingModifiers) == .command
  }

  static func direction(
    forKeyCode keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    hasMarkedText: Bool,
    allowsHorizontalNavigation: Bool = false
  ) -> MoveCommandDirection? {
    guard !hasMarkedText,
      modifiers.intersection(conflictingModifiers).isEmpty
    else {
      return nil
    }

    switch Int(keyCode) {
    case kVK_UpArrow:
      return .up
    case kVK_DownArrow:
      return .down
    case kVK_LeftArrow where allowsHorizontalNavigation:
      return .left
    case kVK_RightArrow where allowsHorizontalNavigation:
      return .right
    default:
      return nil
    }
  }
}

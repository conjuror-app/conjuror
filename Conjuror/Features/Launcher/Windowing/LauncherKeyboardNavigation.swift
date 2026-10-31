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

  /// The modifiers that change a key's meaning, ignoring Caps Lock, Fn, and similar flags.
  static func relevantModifiers(_ modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
    modifiers.intersection(conflictingModifiers)
  }

  static func cyclesMode(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
    Int(keyCode) == kVK_Tab && relevantModifiers(modifiers).isEmpty
  }

  static func revealsSelection(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
    [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(keyCode))
      && relevantModifiers(modifiers) == .command
  }

  static func direction(
    forKeyCode keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    hasMarkedText: Bool,
    allowsHorizontalNavigation: Bool = false
  ) -> MoveCommandDirection? {
    guard !hasMarkedText,
      relevantModifiers(modifiers).isEmpty
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

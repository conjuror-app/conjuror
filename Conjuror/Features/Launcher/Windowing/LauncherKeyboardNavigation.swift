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

  /// Whether a key event is Return or Enter repeating while held, which must not run or confirm
  /// another result.
  static func isRepeatedSubmit(keyCode: UInt16, isARepeat: Bool) -> Bool {
    isARepeat && [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(keyCode))
  }

  /// Running app commands use Command so they never reach the search field. Command-Q still
  /// quits Conjuror and Command-Return still reveals the selection.
  static func runningApplicationCommand(
    keyCode: UInt16,
    charactersIgnoringModifiers: String?,
    modifiers: NSEvent.ModifierFlags
  ) -> RunningApplicationCommand? {
    let modifiers = relevantModifiers(modifiers)

    if Int(keyCode) == kVK_Delete {
      switch modifiers {
      case .command: return .quit
      case [.command, .option]: return .forceQuit
      case [.command, .shift]: return .quitAll
      default: return nil
      }
    }

    switch (modifiers, charactersIgnoringModifiers?.lowercased()) {
    case (.command, "h"): return .hide
    case ([.command, .option], "h"): return .hideOthers
    case (.command, "r"): return .relaunch
    default: return nil
    }
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

import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
  var onMoveSelection: ((MoveCommandDirection) -> Void)?
  var onCycleMode: (() -> Void)?
  var allowsHorizontalNavigation: (() -> Bool)?
  var onOpenSettings: (() -> Void)?
  var onTerminate: (() -> Void) = { NSApp.terminate(nil) }

  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown,
      event.keyCode == 48,
      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    {
      onCycleMode?()
      return
    }

    if event.type == .keyDown,
      let direction = LauncherKeyboardNavigation.direction(
        forKeyCode: event.keyCode,
        modifiers: event.modifierFlags,
        hasMarkedText: (firstResponder as? NSTextView)?.hasMarkedText() == true,
        allowsHorizontalNavigation: allowsHorizontalNavigation?() == true
      )
    {
      onMoveSelection?(direction)
      return
    }

    super.sendEvent(event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if LauncherKeyboardNavigation.hasOnlyCommandModifier(event.modifierFlags) {
      switch event.charactersIgnoringModifiers?.lowercased() {
      case ",":
        onOpenSettings?()
        return true
      case "q":
        onTerminate()
        return true
      default:
        break
      }
    }

    let modifiers = event.modifierFlags.intersection([
      .command,
      .control,
      .option,
      .shift,
    ])
    if let command = LauncherTextEditingCommand.command(
      charactersIgnoringModifiers: event.charactersIgnoringModifiers,
      modifiers: modifiers
    ), firstResponder is NSTextView {
      return NSApp.sendAction(command.action, to: nil, from: self)
    }

    return super.performKeyEquivalent(with: event)
  }
}

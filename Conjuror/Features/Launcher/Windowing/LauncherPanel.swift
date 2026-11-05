import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
  var onMoveSelection: ((MoveCommandDirection) -> Void)?
  var onCycleMode: (() -> Void)?
  var onRevealSelection: (() -> Void)?
  var onOpenWebSearch: (() -> Void)?
  var allowsHorizontalNavigation: (() -> Bool)?
  var handlesRunningApplicationCommands: (() -> Bool)?
  var onRunningApplicationCommand: ((RunningApplicationCommand) -> Void)?
  var onOpenSettings: (() -> Void)?
  var onTerminate: (() -> Void) = { NSApp.terminate(nil) }

  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown,
      LauncherKeyboardNavigation.isRepeatedSubmit(
        keyCode: event.keyCode,
        isARepeat: event.isARepeat
      )
    {
      return
    }

    if event.type == .keyDown,
      LauncherKeyboardNavigation.cyclesMode(keyCode: event.keyCode, modifiers: event.modifierFlags)
    {
      onCycleMode?()

      return
    }

    if event.type == .keyDown,
      LauncherKeyboardNavigation.revealsSelection(
        keyCode: event.keyCode,
        modifiers: event.modifierFlags
      )
    {
      onRevealSelection?()

      return
    }

    // Always consumed, so Option-Return never inserts a line break in the search field.
    if event.type == .keyDown,
      LauncherKeyboardNavigation.opensWebSearch(
        keyCode: event.keyCode,
        modifiers: event.modifierFlags
      )
    {
      onOpenWebSearch?()

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
    let modifiers = LauncherKeyboardNavigation.relevantModifiers(event.modifierFlags)

    if handlesRunningApplicationCommands?() == true,
      let command = LauncherKeyboardNavigation.runningApplicationCommand(
        keyCode: event.keyCode,
        charactersIgnoringModifiers: event.charactersIgnoringModifiers,
        modifiers: modifiers
      )
    {
      onRunningApplicationCommand?(command)

      return true
    }

    if modifiers == .command {
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

    if let command = LauncherTextEditingCommand.command(
      charactersIgnoringModifiers: event.charactersIgnoringModifiers,
      modifiers: modifiers
    ), firstResponder is NSTextView {
      return NSApp.sendAction(command.action, to: nil, from: self)
    }

    return super.performKeyEquivalent(with: event)
  }
}

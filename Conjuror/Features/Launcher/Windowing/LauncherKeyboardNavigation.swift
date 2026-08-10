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

    static func direction(
        forKeyCode keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        hasMarkedText: Bool
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
        default:
            return nil
        }
    }
}

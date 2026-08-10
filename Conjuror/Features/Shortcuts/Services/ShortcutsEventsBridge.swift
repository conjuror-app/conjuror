import AppKit
import Foundation

enum ShortcutsEventsBridge {
    static func loadShortcuts() throws -> [AppleShortcut] {
        let source = """
        tell application id "com.apple.shortcuts.events"
            set shortcutRecords to {}
            repeat with candidate in shortcuts
                set end of shortcutRecords to {id of candidate as text, name of candidate as text, subtitle of candidate as text, accepts input of candidate}
            end repeat
            return shortcutRecords
        end tell
        """
        let descriptor = try execute(source)
        return try parseShortcutList(descriptor)
    }

    static func runShortcut(identifier: String) throws {
        _ = try execute(runScript(identifier: identifier))
    }

    static func runScript(identifier: String) -> String {
        let escapedIdentifier = identifier
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application id "com.apple.shortcuts.events"
            run shortcut id "\(escapedIdentifier)"
        end tell
        """
    }

    static func parseShortcutList(
        _ descriptor: NSAppleEventDescriptor
    ) throws -> [AppleShortcut] {
        guard descriptor.numberOfItems > 0 else {
            return []
        }

        return try (1...descriptor.numberOfItems).map { index in
            guard let record = descriptor.atIndex(index),
                  record.numberOfItems >= 4,
                  let identifier = record.atIndex(1)?.stringValue,
                  let name = record.atIndex(2)?.stringValue
            else {
                throw ShortcutAutomationError.invalidResponse
            }

            return AppleShortcut(
                id: identifier,
                name: name,
                subtitle: record.atIndex(3)?.stringValue ?? "",
                acceptsInput: record.atIndex(4)?.booleanValue ?? false
            )
        }
    }

    private static func execute(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw ShortcutAutomationError.invalidScript
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = errorInfo["NSAppleScriptErrorNumber"] as? Int
            let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                ?? "Shortcuts returned an unknown error."
            if number == -1743 || number == -10004 {
                throw ShortcutAutomationError.permissionDenied
            }
            throw ShortcutAutomationError.executionFailed(message)
        }
        return result
    }
}

enum ShortcutAutomationError: LocalizedError {
    case executionFailed(String)
    case invalidResponse
    case invalidScript
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case let .executionFailed(message):
            return message
        case .invalidResponse:
            return "Shortcuts returned an invalid response."
        case .invalidScript:
            return "Conjuror couldn’t prepare the Shortcuts request."
        case .permissionDenied:
            return "Allow Conjuror to control Shortcuts Events in System Settings > Privacy & Security > Automation."
        }
    }
}

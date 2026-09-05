import AppKit
import Foundation
import ImageIO

enum ShortcutsEventsBridge {
  static func loadShortcuts() throws -> [AppleShortcut] {
    let source = """
      tell application id "com.apple.shortcuts.events"
          set shortcutRecords to {}
          repeat with candidate in shortcuts
              set shortcutColor to color of candidate
              set {redValue, greenValue, blueValue} to shortcutColor
              set end of shortcutRecords to {id of candidate as text, name of candidate as text, subtitle of candidate as text, accepts input of candidate, {redValue, greenValue, blueValue}, icon of candidate, action count of candidate}
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
    let escapedIdentifier =
      identifier
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
        acceptsInput: record.atIndex(4)?.booleanValue ?? false,
        actionCount: record.numberOfItems >= 7
          ? Int(record.atIndex(7)?.int32Value ?? 0)
          : nil,
        color: shortcutColor(from: record.atIndex(5)),
        iconData: compressedIconData(from: record.atIndex(6))
      )
    }
  }

  private static func shortcutColor(
    from descriptor: NSAppleEventDescriptor?
  ) -> AppleShortcut.Color? {
    guard let descriptor,
      descriptor.numberOfItems == 3,
      let red = descriptor.atIndex(1),
      let green = descriptor.atIndex(2),
      let blue = descriptor.atIndex(3)
    else {
      return nil
    }

    return AppleShortcut.Color(
      red: UInt16(clamping: red.int32Value),
      green: UInt16(clamping: green.int32Value),
      blue: UInt16(clamping: blue.int32Value)
    )
  }

  private static func compressedIconData(
    from descriptor: NSAppleEventDescriptor?
  ) -> Data? {
    guard let descriptor,
      let source = CGImageSourceCreateWithData(
        descriptor.data as CFData,
        [kCGImageSourceShouldCache: false] as CFDictionary
      ),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          // The launcher displays icons at 26 points, including on Retina screens.
          kCGImageSourceThumbnailMaxPixelSize: 64,
        ] as CFDictionary
      )
    else {
      return nil
    }
    return NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:])
  }

  private static func execute(_ source: String) throws -> NSAppleEventDescriptor {
    guard let script = NSAppleScript(source: source) else {
      throw ShortcutAutomationError.invalidScript
    }

    var errorInfo: NSDictionary?
    let result = script.executeAndReturnError(&errorInfo)
    if let errorInfo {
      let number = errorInfo["NSAppleScriptErrorNumber"] as? Int
      let message =
        errorInfo["NSAppleScriptErrorMessage"] as? String
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
      return
        "Allow Conjuror to control Shortcuts Events in System Settings > Privacy & Security > Automation."
    }
  }
}

import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
protocol ClipboardPasting {
  /// Whether macOS lets Conjuror send keystrokes, which pasting needs.
  var canPaste: Bool { get }

  /// Pastes the clipboard into the frontmost app once Conjuror has handed focus back.
  func paste()
}

/// Pastes by sending Command-V, which needs Accessibility access.
struct KeystrokeClipboardPaster: ClipboardPasting {
  private static let activationTimeout: Duration = .milliseconds(500)
  private static let activationPollInterval: Duration = .milliseconds(20)
  /// Some apps ignore a paste that arrives in the same moment they become active.
  private static let settleDelay: Duration = .milliseconds(50)

  /// Shows the system prompt that sends the user to Accessibility settings.
  static func requestAccess() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  private static func postCommandV() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyCode = CGKeyCode(kVK_ANSI_V)

    for isKeyDown in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown)
      event?.flags = .maskCommand
      event?.post(tap: .cghidEventTap)
    }
  }

  var canPaste: Bool { AXIsProcessTrusted() }

  func paste() {
    Task { @MainActor in
      var waited = Duration.zero

      while NSWorkspace.shared.frontmostApplication == .current, waited < Self.activationTimeout {
        try? await Task.sleep(for: Self.activationPollInterval)
        waited += Self.activationPollInterval
      }

      try? await Task.sleep(for: Self.settleDelay)
      Self.postCommandV()
    }
  }
}

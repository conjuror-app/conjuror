import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
protocol ClipboardPasting {
  var canPaste: Bool { get }

  func paste()
}

struct KeystrokeClipboardPaster: ClipboardPasting {
  private static let activationTimeout: Duration = .milliseconds(500)
  private static let activationPollInterval: Duration = .milliseconds(20)
  private static let settleDelay: Duration = .milliseconds(50)

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

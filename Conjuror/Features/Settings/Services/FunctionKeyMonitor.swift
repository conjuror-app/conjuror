import AppKit
import ApplicationServices

/// Recognises a tap of the fn (Globe) key on its own: pressed and released quickly, with no
/// other key or modifier used in between.
struct FunctionKeyTapDetector {
  static let maximumTapDuration: TimeInterval = 0.5

  private var isFunctionKeyDown = false
  private var pressedAt: TimeInterval?

  /// Handles a modifier change and returns true when it completes a tap.
  mutating func handleModifierChange(
    _ flags: NSEvent.ModifierFlags,
    at timestamp: TimeInterval
  ) -> Bool {
    let flags = flags.intersection(.deviceIndependentFlagsMask)
    let isDown = flags.contains(.function)
    let hasOtherModifiers = !flags.intersection([.command, .control, .option, .shift]).isEmpty
    defer { isFunctionKeyDown = isDown }

    switch (isFunctionKeyDown, isDown) {
    case (false, true):
      pressedAt = hasOtherModifiers ? nil : timestamp

      return false
    case (true, false):
      defer { pressedAt = nil }
      guard let pressedAt, !hasOtherModifiers else { return false }

      return timestamp - pressedAt <= Self.maximumTapDuration
    default:
      pressedAt = nil

      return false
    }
  }

  mutating func handleKeyDown() {
    pressedAt = nil
  }
}

/// Watches for fn taps in every app, including Conjuror. macOS only delivers other apps' key
/// events to processes trusted for Accessibility.
@MainActor
final class FunctionKeyMonitor {
  /// The system-defined event subtype for media, brightness, and volume keys
  /// (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`), which don't arrive as key-down events.
  private static let auxControlButtonsSubtype: Int16 = 8

  private var detector = FunctionKeyTapDetector()
  private var monitors = [Any]()
  private let handler: () -> Void

  init(handler: @escaping () -> Void) throws {
    guard AXIsProcessTrusted() else {
      throw FunctionKeyMonitorError.accessibilityRequired
    }

    self.handler = handler

    let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .systemDefined]
    let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) }
    }
    let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) }

      return event
    }

    guard let global, let local else {
      [global, local].compactMap { $0 }.forEach(NSEvent.removeMonitor)
      throw FunctionKeyMonitorError.accessibilityRequired
    }

    monitors = [global, local]
  }

  isolated deinit {
    monitors.forEach(NSEvent.removeMonitor)
  }

  private func handle(_ event: NSEvent) {
    switch event.type {
    case .flagsChanged:
      if detector.handleModifierChange(event.modifierFlags, at: event.timestamp) {
        handler()
      }
    case .keyDown:
      detector.handleKeyDown()
    case .systemDefined where event.subtype.rawValue == Self.auxControlButtonsSubtype:
      detector.handleKeyDown()
    default:
      break
    }
  }
}

private enum FunctionKeyMonitorError: LocalizedError {
  case accessibilityRequired

  var errorDescription: String? {
    "The fn shortcut needs Accessibility access in System Settings."
  }
}

enum GlobeKeySystemAction {
  /// Whether macOS does something itself when the Globe key is pressed, as set by
  /// "Press 🌐 key to" in System Settings → Keyboard. Unset means the system default,
  /// which is an action.
  static var isEnabled: Bool {
    let value = CFPreferencesCopyAppValue(
      "AppleFnUsageType" as CFString,
      "com.apple.HIToolbox" as CFString
    )

    return (value as? Int) != 0
  }
}

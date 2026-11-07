import AppKit

/// The parts of a pasteboard the monitor reads, so tests can supply their own.
@MainActor
protocol ClipboardPasteboard: AnyObject {
  var changeCount: Int { get }
  var typeIdentifiers: [String] { get }

  func text() -> String?
}

/// Watches the general pasteboard for copies. macOS doesn't announce clipboard changes, so it
/// compares the change count on a timer and only reads the contents when the count moves.
@MainActor
final class ClipboardMonitor {
  private static let pollInterval: TimeInterval = 0.5

  static func frontmostSource() -> ClipboardSource? {
    guard let application = NSWorkspace.shared.frontmostApplication else { return nil }

    return ClipboardSource(
      name: application.localizedName,
      bundleIdentifier: application.bundleIdentifier
    )
  }

  var isRunning: Bool { timer != nil }

  private let pasteboard: ClipboardPasteboard
  private let policy: ClipboardCapturePolicy
  private let currentSource: @MainActor () -> ClipboardSource?
  private let onCapture: @MainActor (String, ClipboardSource?) -> Void
  private var lastChangeCount: Int
  private var timer: Timer?

  init(
    pasteboard: ClipboardPasteboard = GeneralClipboardPasteboard(),
    policy: ClipboardCapturePolicy = ClipboardCapturePolicy(),
    currentSource: @escaping @MainActor () -> ClipboardSource? = ClipboardMonitor.frontmostSource,
    onCapture: @escaping @MainActor (String, ClipboardSource?) -> Void
  ) {
    self.pasteboard = pasteboard
    self.policy = policy
    self.currentSource = currentSource
    self.onCapture = onCapture
    lastChangeCount = pasteboard.changeCount
  }

  /// Starts watching. Whatever is on the clipboard already isn't recorded.
  func start() {
    guard timer == nil else { return }

    lastChangeCount = pasteboard.changeCount
    let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.checkForChanges() }
    }
    timer.tolerance = Self.pollInterval / 2
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  /// Records the clipboard's text if it changed since the last check.
  func checkForChanges() {
    let changeCount = pasteboard.changeCount

    guard changeCount != lastChangeCount else { return }

    lastChangeCount = changeCount
    let source = currentSource()

    guard policy.allowsReading(types: pasteboard.typeIdentifiers, source: source),
      let text = policy.capturedText(pasteboard.text())
    else { return }

    onCapture(text, source)
  }
}

final class GeneralClipboardPasteboard: ClipboardPasteboard {
  private let pasteboard = NSPasteboard.general

  var changeCount: Int { pasteboard.changeCount }
  var typeIdentifiers: [String] { pasteboard.types?.map(\.rawValue) ?? [] }

  func text() -> String? {
    pasteboard.string(forType: .string)
  }
}

import AppKit

@MainActor
protocol ClipboardPasteboard: AnyObject {
  var changeCount: Int { get }
  var typeIdentifiers: [String] { get }

  func text() -> String?
}

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

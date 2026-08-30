import AppKit

@MainActor
final class ClipboardMonitor {
  private static let concealedType = NSPasteboard.PasteboardType(
    "org.nspasteboard.ConcealedType"
  )
  private static let transientType = NSPasteboard.PasteboardType(
    "org.nspasteboard.TransientType"
  )

  private let pasteboard: NSPasteboard
  private let onTextCopied: (String) -> Void
  private var timer: Timer?
  private var changeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    onTextCopied: @escaping (String) -> Void
  ) {
    self.pasteboard = pasteboard
    self.onTextCopied = onTextCopied
    changeCount = pasteboard.changeCount
  }

  func start() {
    guard timer == nil else { return }
    changeCount = pasteboard.changeCount
    timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.captureIfChanged() }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func write(_ text: String) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    changeCount = pasteboard.changeCount
  }

  func captureIfChanged() {
    guard pasteboard.changeCount != changeCount else { return }
    changeCount = pasteboard.changeCount
    let types = Set(pasteboard.types ?? [])
    guard !types.contains(Self.concealedType),
      !types.contains(Self.transientType),
      let text = pasteboard.string(forType: .string)
    else { return }
    onTextCopied(text)
  }
}

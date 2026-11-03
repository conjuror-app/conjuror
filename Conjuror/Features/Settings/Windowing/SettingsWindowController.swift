import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private static let windowSize = NSSize(width: 640, height: 420)

  private let onClose: () -> Void

  init(
    store: SettingsStore,
    launcherStore: LauncherStore,
    hotKeyStore: HotKeyStore,
    currencyRateStore: CurrencyRateStore,
    launchAtLoginStore: LaunchAtLoginStore,
    onClose: @escaping () -> Void
  ) {
    self.onClose = onClose
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.windowSize),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Settings"
    window.isReleasedWhenClosed = false
    window.animationBehavior = .documentWindow
    window.collectionBehavior = [.moveToActiveSpace]
    window.contentViewController = NSHostingController(
      rootView: SettingsView(
        store: store,
        launcherStore: launcherStore,
        hotKeyStore: hotKeyStore,
        currencyRateStore: currencyRateStore,
        launchAtLoginStore: launchAtLoginStore
      )
    )
    window.setContentSize(Self.windowSize)

    super.init(window: window)
    window.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let window else {
      return
    }

    if !window.isVisible {
      window.center()
    }

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(nil)
  }

  func windowWillClose(_ notification: Notification) {
    window?.contentViewController = nil
    onClose()
  }
}

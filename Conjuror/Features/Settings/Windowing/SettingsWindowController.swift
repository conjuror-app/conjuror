import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  private static let windowSize = NSSize(width: 520, height: 280)

  init(
    store: SettingsStore,
    hotKeyStore: HotKeyStore,
    currencyRateStore: CurrencyRateStore
  ) {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.windowSize),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Settings"
    window.isReleasedWhenClosed = false
    window.animationBehavior = .documentWindow
    window.contentViewController = NSHostingController(
      rootView: SettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        currencyRateStore: currencyRateStore
      )
    )
    window.setContentSize(Self.windowSize)

    super.init(window: window)
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
}

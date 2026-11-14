import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private static let windowSize = NSSize(width: 640, height: 560)
  /// Tall enough for the Apps pane's lists. The width is fixed; only the height resizes.
  private static let minimumWindowSize = NSSize(width: 640, height: 500)

  /// Keeps the fixed width and at least the minimum height.
  private static func constrained(_ size: NSSize) -> NSSize {
    NSSize(
      width: minimumWindowSize.width,
      height: max(size.height, minimumWindowSize.height)
    )
  }

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
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Settings"
    // The sidebar runs under the title bar and the pane title sits in it. An empty toolbar
    // gives the title bar its taller, unified height.
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.toolbar = NSToolbar()
    window.toolbarStyle = .unified
    window.isReleasedWhenClosed = false
    window.animationBehavior = .documentWindow
    window.collectionBehavior = [.moveToActiveSpace]
    let hostingController = NSHostingController(
      rootView: SettingsView(
        store: store,
        launcherStore: launcherStore,
        hotKeyStore: hotKeyStore,
        currencyRateStore: currencyRateStore,
        launchAtLoginStore: launchAtLoginStore
      )
    )
    // The window's size limits apply, rather than the SwiftUI content's.
    hostingController.sizingOptions = []
    window.contentViewController = hostingController
    window.contentMinSize = Self.minimumWindowSize
    window.contentMaxSize = NSSize(
      width: Self.minimumWindowSize.width,
      height: .greatestFiniteMagnitude
    )
    window.setContentSize(Self.windowSize)
    window.setFrameAutosaveName("Settings")
    // A restored frame keeps its height, but never a different width.
    window.setContentSize(
      Self.constrained(window.contentRect(forFrameRect: window.frame).size)
    )

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

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    let contentSize = sender.contentRect(
      forFrameRect: NSRect(origin: .zero, size: frameSize)
    ).size

    return sender.frameRect(
      forContentRect: NSRect(origin: .zero, size: Self.constrained(contentSize))
    ).size
  }

  func windowWillClose(_ notification: Notification) {
    window?.contentViewController = nil
    onClose()
  }
}

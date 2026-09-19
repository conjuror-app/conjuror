import AppKit
import SwiftUI

@MainActor
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
  private static func resize(
    _ window: NSWindow,
    height: CGFloat
  ) {
    let targetSize = LauncherLayout.windowSize(contentHeight: height)
    let targetFrame = LauncherWindowGeometry.resizedFrame(
      currentFrame: window.frame,
      targetSize: targetSize,
      visibleFrame: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    )
    guard window.frame != targetFrame else {
      return
    }

    window.setFrame(targetFrame, display: true)
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  private let store: LauncherStore
  private let settingsStore: SettingsStore
  private let onHide: () -> Void

  init(
    store: LauncherStore,
    settingsStore: SettingsStore,
    hotKeyStore: HotKeyStore,
    onHide: @escaping () -> Void,
    onOpenSettings: @escaping () -> Void
  ) {
    self.store = store
    self.settingsStore = settingsStore
    self.onHide = onHide

    let initialSize = LauncherLayout.windowSize(
      contentHeight: LauncherLayout(appearance: settingsStore.launcherAppearance).collapsedHeight
    )
    let panel = LauncherPanel(
      contentRect: NSRect(origin: .zero, size: initialSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    // Liquid Glass provides its own shaped edge and shadow. The window's
    // legacy shadow follows the rectangular panel bounds.
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = false
    panel.level = .floating
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
    panel.onMoveSelection = { [weak store] direction in
      store?.moveSelection(direction)
    }
    panel.onCycleMode = { [weak store] in
      store?.cycleMode()
    }
    panel.onOpenSettings = onOpenSettings
    panel.allowsHorizontalNavigation = { [weak store] in
      store?.mode == .emoji
    }

    let contentView = LauncherView(
      store: store,
      settingsStore: settingsStore,
      hotKeyStore: hotKeyStore,
      onHide: onHide,
      onHeightChange: { [weak panel] height in
        guard let panel else {
          return
        }
        Self.resize(panel, height: height)
      }
    )
    panel.contentViewController = NSHostingController(rootView: contentView)
    panel.setContentSize(initialSize)

    super.init(window: panel)
    panel.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func toggle(mode: LauncherMode) {
    if isVisible, store.mode == mode {
      onHide()
    } else {
      show(mode: mode)
    }
  }

  func show(mode: LauncherMode? = nil) {
    guard let window else {
      return
    }

    store.prepareForActivation(mode: mode)
    Self.resize(
      window,
      height: LauncherLayout(appearance: settingsStore.launcherAppearance).collapsedHeight
    )
    placeOnPreferredScreen(window)
    NSApp.unhide(nil)
    window.makeKeyAndOrderFront(nil)

    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window else {
        return
      }

      window.makeKey()
      self.focusSearchField(in: window)
    }
  }

  func hide() {
    window?.orderOut(nil)
    window?.contentViewController = nil
  }

  func windowDidResignKey(_ notification: Notification) {
    onHide()
  }

  private func placeOnPreferredScreen(_ window: NSWindow) {
    guard let screen = preferredScreen() else {
      window.center()
      return
    }

    window.setFrame(
      LauncherWindowGeometry.centeredFrame(
        size: window.frame.size,
        visibleFrame: screen.visibleFrame
      ),
      display: true
    )
  }

  private func preferredScreen() -> NSScreen? {
    let pointerLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { screen in
      screen.frame.contains(pointerLocation)
    } ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func focusSearchField(in window: NSWindow) {
    guard let contentView = window.contentView,
      let searchField = firstEditableTextField(in: contentView)
    else {
      return
    }

    window.makeFirstResponder(searchField)
  }

  private func firstEditableTextField(in view: NSView) -> NSTextField? {
    if let textField = view as? NSTextField, textField.isEditable {
      return textField
    }

    for subview in view.subviews {
      if let textField = firstEditableTextField(in: subview) {
        return textField
      }
    }

    return nil
  }
}

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

    window.setFrame(targetFrame, display: false)
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  private let store: LauncherStore
  private let settingsStore: SettingsStore
  private let onHide: (_ restoringFocus: Bool) -> Void
  private var resizeWorkItem: DispatchWorkItem?
  private var previousApplication: NSRunningApplication?

  init(
    store: LauncherStore,
    settingsStore: SettingsStore,
    hotKeyStore: HotKeyStore,
    onHide: @escaping (_ restoringFocus: Bool) -> Void,
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
    // Glass draws the rounded shadow. The panel shadow would add a rectangular edge.
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = false
    panel.level = .floating
    // Hiding immediately releases the content, so no window animation may outlive it.
    panel.animationBehavior = .none
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
    panel.onMoveSelection = { [weak store] direction in
      store?.moveSelection(direction)
    }

    panel.onCycleMode = { [weak store] in
      store?.cycleMode()
    }

    panel.onRevealSelection = { [weak store] in
      store?.revealSelectedResult()
    }

    panel.onOpenSettings = onOpenSettings
    panel.allowsHorizontalNavigation = { [weak store] in
      store?.mode.allowsHorizontalNavigation == true
    }

    super.init(window: panel)

    let contentView = LauncherView(
      store: store,
      settingsStore: settingsStore,
      hotKeyStore: hotKeyStore,
      // Escape dismisses without choosing another app, so focus returns to the previous one.
      onHide: { onHide(true) },
      onHeightChange: { [weak self] height in
        self?.scheduleResize(height: height)
      }
    )
    panel.contentViewController = NSHostingController(rootView: contentView)
    panel.setContentSize(initialSize)

    panel.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func toggle(mode: LauncherMode) {
    if isVisible, store.mode == mode {
      onHide(true)
    } else {
      show(mode: mode)
    }
  }

  func show(mode: LauncherMode? = nil) {
    guard let window else {
      return
    }

    if !window.isVisible {
      previousApplication = Self.otherFrontmostApplication()
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

  func hide(restoringFocus: Bool = false) {
    resizeWorkItem?.cancel()
    resizeWorkItem = nil
    window?.orderOut(nil)
    window?.contentViewController = nil

    // Activating a hidden app unhides it, so leave an app the user just hid or quit alone.
    if restoringFocus, let previousApplication, !previousApplication.isTerminated,
      !previousApplication.isHidden
    {
      // The panel took key focus, so hand it back to the app the user was typing in.
      previousApplication.activate(from: .current)
    }

    previousApplication = nil
  }

  func windowDidResignKey(_ notification: Notification) {
    onHide(false)
  }

  private static func otherFrontmostApplication() -> NSRunningApplication? {
    guard let application = NSWorkspace.shared.frontmostApplication,
      application != .current
    else {
      return nil
    }

    return application
  }

  private func scheduleResize(height: CGFloat) {
    resizeWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, let window = self.window, window.contentViewController != nil else {
        return
      }

      self.resizeWorkItem = nil
      Self.resize(window, height: height)
    }

    resizeWorkItem = workItem
    // SwiftUI may report the height during layout. Resize after that update finishes.
    DispatchQueue.main.async(execute: workItem)
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

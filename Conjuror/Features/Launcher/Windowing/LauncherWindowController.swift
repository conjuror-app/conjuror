import AppKit
import SwiftUI

@MainActor
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
  private static func resize(
    _ window: NSWindow,
    appearance: LauncherAppearance,
    height: CGFloat
  ) {
    let targetSize = LauncherLayout(appearance: appearance).windowSize(contentHeight: height)
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

  private static func otherFrontmostApplication() -> NSRunningApplication? {
    guard let application = NSWorkspace.shared.frontmostApplication,
      application != .current
    else {
      return nil
    }

    return application
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

    let initialLayout = LauncherLayout(appearance: settingsStore.launcherAppearance)
    let initialSize = initialLayout.windowSize(contentHeight: initialLayout.collapsedHeight)
    let panel = LauncherPanel(
      contentRect: NSRect(origin: .zero, size: initialSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = false
    panel.level = .floating
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

    panel.onOpenWebSearch = { [weak store] in
      store?.openWebSearch()
    }

    panel.handlesRunningApplicationCommands = { [weak store] in
      store?.handlesRunningApplicationCommands == true
    }

    panel.onRunningApplicationCommand = { [weak store] command in
      store?.perform(command)
    }

    panel.handlesClipboardCommands = { [weak store] in
      store?.handlesClipboardCommands == true
    }

    panel.onDeleteClipboardItem = { [weak store] in
      store?.deleteSelectedClipboardItem()
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
    let currentLayout = LauncherLayout(appearance: settingsStore.launcherAppearance)
    Self.resize(
      window,
      appearance: currentLayout.appearance,
      height: currentLayout.collapsedHeight
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

    if restoringFocus, let previousApplication, !previousApplication.isTerminated,
      !previousApplication.isHidden
    {
      previousApplication.activate(from: .current)
    }

    previousApplication = nil
  }

  func windowDidResignKey(_ notification: Notification) {
    onHide(false)
  }

  private func scheduleResize(height: CGFloat) {
    resizeWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, let window = self.window, window.contentViewController != nil else {
        return
      }

      self.resizeWorkItem = nil
      Self.resize(window, appearance: self.settingsStore.launcherAppearance, height: height)
    }

    resizeWorkItem = workItem
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

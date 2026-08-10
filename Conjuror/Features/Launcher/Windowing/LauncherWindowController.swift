import AppKit
import SwiftUI

@MainActor
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
  private static let collapsedWindowSize = NSSize(
    width: LauncherLayout.width,
    height: LauncherLayout.collapsedHeight
  )

  private static func resize(
    _ window: NSWindow,
    height: CGFloat
  ) {
    let targetSize = NSSize(
      width: LauncherLayout.width,
      height: height
    )
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

  init(
    store: LauncherStore,
    settingsStore: SettingsStore,
    hotKeyStore: HotKeyStore,
    onOpenSettings: @escaping () -> Void
  ) {
    self.store = store

    let panel = LauncherPanel(
      contentRect: NSRect(origin: .zero, size: Self.collapsedWindowSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    if #available(macOS 26.0, *) {
      // Liquid Glass provides its own shaped edge and shadow. The window's
      // legacy shadow follows the rectangular panel bounds.
      panel.hasShadow = false
    } else {
      panel.hasShadow = true
    }
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = false
    panel.level = .floating
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
    panel.onMoveSelection = { [weak store] direction in
      store?.moveSelection(direction)
    }
    panel.onOpenSettings = onOpenSettings

    let contentView = LauncherView(
      store: store,
      settingsStore: settingsStore,
      hotKeyStore: hotKeyStore,
      onHide: { [weak panel] in
        panel?.orderOut(nil)
      },
      onHeightChange: { [weak panel] height in
        guard let panel else {
          return
        }
        Self.resize(panel, height: height)
      }
    )
    panel.contentViewController = NSHostingController(rootView: contentView)
    panel.setContentSize(Self.collapsedWindowSize)

    super.init(window: panel)
    panel.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let window else {
      return
    }

    store.prepareForActivation()
    Self.resize(window, height: LauncherLayout.collapsedHeight)
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
  }

  func windowDidResignKey(_ notification: Notification) {
    hide()
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

private final class LauncherPanel: NSPanel {
  var onMoveSelection: ((MoveCommandDirection) -> Void)?
  var onOpenSettings: (() -> Void)?

  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown,
      let direction = LauncherKeyboardNavigation.direction(
        forKeyCode: event.keyCode,
        modifiers: event.modifierFlags,
        hasMarkedText: (firstResponder as? NSTextView)?.hasMarkedText() == true
      )
    {
      onMoveSelection?(direction)
      return
    }

    super.sendEvent(event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if LauncherKeyboardNavigation.hasOnlyCommandModifier(event.modifierFlags) {
      switch event.charactersIgnoringModifiers?.lowercased() {
      case ",":
        onOpenSettings?()
        return true
      case "q":
        NSApp.terminate(nil)
        return true
      default:
        break
      }
    }

    if let command = LauncherTextEditingCommand.command(
      charactersIgnoringModifiers: event.charactersIgnoringModifiers,
      modifiers: modifiers
    ), firstResponder is NSTextView {
      return NSApp.sendAction(command.action, to: nil, from: self)
    }

    return super.performKeyEquivalent(with: event)
  }
}

enum LauncherTextEditingCommand: Equatable {
  case copy
  case cut
  case paste
  case redo
  case selectAll
  case undo

  static func command(
    charactersIgnoringModifiers: String?,
    modifiers: NSEvent.ModifierFlags
  ) -> Self? {
    let key = charactersIgnoringModifiers?.lowercased()
    switch (modifiers, key) {
    case (.command, "a"): return .selectAll
    case (.command, "c"): return .copy
    case (.command, "v"): return .paste
    case (.command, "x"): return .cut
    case (.command, "z"): return .undo
    case ([.command, .shift], "z"): return .redo
    default: return nil
    }
  }

  var action: Selector {
    switch self {
    case .copy: #selector(NSText.copy(_:))
    case .cut: #selector(NSText.cut(_:))
    case .paste: #selector(NSText.paste(_:))
    case .redo: Selector(("redo:"))
    case .selectAll: #selector(NSText.selectAll(_:))
    case .undo: Selector(("undo:"))
    }
  }
}

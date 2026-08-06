import AppKit
import SwiftUI

@MainActor
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    private static let windowSize = NSSize(width: 620, height: 400)

    private let store: LauncherStore

    init(store: LauncherStore, hotKeyErrorMessage: String?) {
        self.store = store

        let panel = LauncherPanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]

        let contentView = ContentView(
            store: store,
            hotKeyErrorMessage: hotKeyErrorMessage,
            onHide: { [weak panel] in
                panel?.orderOut(nil)
            },
            onQuit: { NSApp.terminate(nil) }
        )
        panel.contentViewController = NSHostingController(rootView: contentView)
        panel.setContentSize(Self.windowSize)

        super.init(window: panel)
        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        guard let window else {
            return
        }

        centerOnMainScreen(window)
        NSApp.unhide(nil)
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            self.store.prepareForActivation()
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

    private func centerOnMainScreen(_ window: NSWindow) {
        guard let screenFrame = NSScreen.main?.frame else {
            window.center()
            return
        }

        window.setFrameOrigin(NSPoint(
            x: screenFrame.midX - Self.windowSize.width / 2,
            y: screenFrame.midY - Self.windowSize.height / 2
        ))
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
    override var canBecomeKey: Bool { true }
}

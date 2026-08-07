import AppKit
import SwiftUI

@MainActor
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    private static let collapsedWindowSize = NSSize(
        width: LauncherLayout.width,
        height: LauncherLayout.collapsedHeight
    )

    private let store: LauncherStore

    init(store: LauncherStore, hotKeyErrorMessage: String?) {
        self.store = store

        let panel = LauncherPanel(
            contentRect: NSRect(origin: .zero, size: Self.collapsedWindowSize),
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

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        guard let window else {
            return
        }

        store.prepareForActivation()
        Self.resize(window, height: LauncherLayout.collapsedHeight)
        centerOnMainScreen(window)
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

    private func centerOnMainScreen(_ window: NSWindow) {
        guard let screenFrame = NSScreen.main?.frame else {
            window.center()
            return
        }

        window.setFrameOrigin(NSPoint(
            x: screenFrame.midX - window.frame.width / 2,
            y: screenFrame.midY
                - window.frame.height / 2
                + screenFrame.height * 0.15
        ))
    }

    private static func resize(
        _ window: NSWindow,
        height: CGFloat
    ) {
        let targetSize = NSSize(
            width: LauncherLayout.width,
            height: height
        )
        guard window.frame.size != targetSize else {
            return
        }

        let currentFrame = window.frame
        let targetFrame = NSRect(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        window.setFrame(targetFrame, display: true)
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "q"
        {
            NSApp.terminate(nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}

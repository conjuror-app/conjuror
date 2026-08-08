import AppKit
import Carbon.HIToolbox
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

    var isVisible: Bool {
        window?.isVisible == true
    }

    private let store: LauncherStore

    init(
        store: LauncherStore,
        settingsStore: SettingsStore,
        hotKeyErrorMessage: String?
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

        let contentView = ContentView(
            store: store,
            settingsStore: settingsStore,
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

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch Int(event.keyCode) {
            case kVK_UpArrow:
                onMoveSelection?(.up)
                return
            case kVK_DownArrow:
                onMoveSelection?(.down)
                return
            default:
                break
            }
        }

        super.sendEvent(event)
    }

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

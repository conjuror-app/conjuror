import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var hotKeyErrorMessage: String?

    lazy var store = LauncherStore(onLaunchSuccess: { [weak self] in
        self?.hideLauncher()
    })

    private weak var launcherWindow: NSWindow?
    private var hotKey: GlobalHotKey?
    private var windowObserver: NSObjectProtocol?
    private var workspaceObservers = [NSObjectProtocol]()
    private var catalogRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotKey()
        observeWorkspaceChanges()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showLauncher()
        return true
    }

    func register(window: NSWindow) {
        guard launcherWindow !== window else {
            return
        }

        launcherWindow = window
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideLauncher()
            }
        }

        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    func toggleLauncher() {
        guard let window = resolvedLauncherWindow else {
            hotKeyErrorMessage = "The launcher window is not available. Quit and reopen Conjuror."
            return
        }

        if window.isVisible {
            hideLauncher()
        } else {
            showLauncher(window)
        }
    }

    func hideLauncher() {
        resolvedLauncherWindow?.orderOut(nil)
        NSApp.hide(nil)
    }

    func showLauncher() {
        guard let window = resolvedLauncherWindow else {
            return
        }
        showLauncher(window)
    }

    private var resolvedLauncherWindow: NSWindow? {
        launcherWindow ?? NSApp.windows.first(where: { $0.canBecomeKey })
    }

    private func showLauncher(_ window: NSWindow) {
        recenter(window)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak window] in
            self?.store.prepareForActivation()
            window?.makeKey()
            if let window {
                self?.focusSearchField(in: window)
            }
        }
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

    private func recenter(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        guard let visibleFrame = activeScreen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - window.frame.width / 2,
            y: visibleFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func registerHotKey() {
        do {
            hotKey = try GlobalHotKey { [weak self] in
                DispatchQueue.main.async {
                    self?.toggleLauncher()
                }
            }
            hotKeyErrorMessage = nil
        } catch {
            hotKey = nil
            hotKeyErrorMessage = error.localizedDescription
        }
    }

    private func observeWorkspaceChanges() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notificationNames: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
        ]

        workspaceObservers = notificationNames.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleCatalogRefresh()
                }
            }
        }
    }

    private func scheduleCatalogRefresh() {
        catalogRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.store.loadApplications()
        }
        catalogRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}

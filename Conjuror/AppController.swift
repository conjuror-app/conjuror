import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private lazy var store = LauncherStore(onLaunchSuccess: { [weak self] in
        self?.hideLauncher()
    })

    private lazy var launcherWindowController = LauncherWindowController(
        store: store,
        hotKeyErrorMessage: hotKeyErrorMessage
    )

    private var hotKeyErrorMessage: String?
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?
    private var workspaceObservers = [NSObjectProtocol]()
    private var catalogRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        registerHotKey()
        observeWorkspaceChanges()
        showLauncher()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showLauncher()
        return true
    }

    func toggleLauncher() {
        if launcherWindowController.isVisible {
            hideLauncher()
        } else {
            showLauncher()
        }
    }

    func hideLauncher() {
        launcherWindowController.hide()
    }

    func showLauncher() {
        launcherWindowController.show()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "wand.and.stars",
                accessibilityDescription: "Conjuror"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Conjuror"
        }

        let menu = NSMenu()
        let showItem = NSMenuItem(
            title: "Show Conjuror",
            action: #selector(showLauncherFromMenu),
            keyEquivalent: " "
        )
        showItem.keyEquivalentModifierMask = [.option]
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Conjuror",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func showLauncherFromMenu() {
        showLauncher()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
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

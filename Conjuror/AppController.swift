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
    private var workspaceObservers = [NSObjectProtocol]()
    private var catalogRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

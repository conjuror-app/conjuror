import AppKit
import Combine

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
  private lazy var settingsStore = SettingsStore()

  private lazy var store = LauncherStore(
    settingsStore: settingsStore,
    onEvent: { [weak self] event in
      guard event != .launchSucceeded else { return }
      self?.hideLauncher()
    }
  )

  private lazy var currencyRateStore = CurrencyRateStore()
  private lazy var launchAtLoginStore = LaunchAtLoginStore()

  private lazy var hotKeyStore = HotKeyStore(
    settingsStore: settingsStore,
    onHotKeyPressed: { [weak self] action in
      Task { @MainActor [weak self] in
        self?.handleHotKey(action)
      }
    }
  )

  private lazy var launcherWindowController = LauncherWindowController(
    store: store,
    settingsStore: settingsStore,
    hotKeyStore: hotKeyStore,
    onOpenSettings: { [weak self] in
      self?.showSettingsFromLauncher()
    }
  )

  private lazy var settingsWindowController = SettingsWindowController(
    store: settingsStore,
    hotKeyStore: hotKeyStore,
    currencyRateStore: currencyRateStore,
    launchAtLoginStore: launchAtLoginStore
  )

  private var statusItem: NSStatusItem?
  private var cancellables = Set<AnyCancellable>()
  private var workspaceObservers = [NSObjectProtocol]()
  private var catalogRefreshWorkItem: DispatchWorkItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configureStatusItem()
    hotKeyStore.register()
    observeWorkspaceChanges()
    observeCurrencyRates()
    currencyRateStore.start()
    store.loadApplications()
    store.loadShortcuts()
  }

  func applicationWillTerminate(_ notification: Notification) {
    catalogRefreshWorkItem?.cancel()
    catalogRefreshWorkItem = nil

    let notificationCenter = NSWorkspace.shared.notificationCenter
    workspaceObservers.forEach(notificationCenter.removeObserver)
    workspaceObservers.removeAll()
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

  private func handleHotKey(_ action: HotKeyAction) {
    switch action {
    case .launcher:
      toggleLauncher()
    case .shortcuts:
      launcherWindowController.toggle(mode: .shortcuts)
    case .emoji:
      launcherWindowController.toggle(mode: .emoji)
    }
  }

  private func showSettingsFromLauncher() {
    settingsWindowController.show()
    hideLauncher()
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
    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(showSettingsFromMenu),
      keyEquivalent: ""
    )
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit",
      action: #selector(quitFromMenu),
      keyEquivalent: "q"
    )
    quitItem.keyEquivalentModifierMask = [.command]
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
    self.statusItem = statusItem
  }

  @objc private func showSettingsFromMenu() {
    settingsWindowController.show()
  }

  @objc private func quitFromMenu() {
    NSApp.terminate(nil)
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

  private func observeCurrencyRates() {
    currencyRateStore.$isEnabled
      .combineLatest(currencyRateStore.$rates)
      .sink { [weak self] isEnabled, rates in
        self?.store.setCurrencySource(isEnabled ? .on(rates) : .off)
      }
      .store(in: &cancellables)
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

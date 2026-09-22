import AppKit
import Combine

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
  private lazy var settingsStore = SettingsStore()
  private lazy var fileSearchService = SpotlightFileSearchService()

  private lazy var store = LauncherStore(
    settingsStore: settingsStore,
    fileSearcher: fileSearchService,
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

  private var statusItem: NSStatusItem?
  private var launcherWindowController: LauncherWindowController?
  private var settingsWindowController: SettingsWindowController?
  private var cancellables = Set<AnyCancellable>()
  private var volumeObservers = [NSObjectProtocol]()
  private let catalogRefresh = Debouncer(delay: 1)
  private lazy var applicationDirectoryMonitor = ApplicationDirectoryMonitor { [weak self] in
    self?.scheduleCatalogRefresh()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configureStatusItem()
    hotKeyStore.register()
    observeVolumeChanges()
    applicationDirectoryMonitor.start(directories: ApplicationCatalog.applicationDirectories())
    observeCurrencyRates()
    currencyRateStore.start()
    store.loadApplications()
  }

  func applicationWillTerminate(_ notification: Notification) {
    applicationDirectoryMonitor.stop()
    catalogRefresh.cancel()

    let notificationCenter = NSWorkspace.shared.notificationCenter
    volumeObservers.forEach(notificationCenter.removeObserver)
    volumeObservers.removeAll()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    showLauncher()

    return true
  }

  func toggleLauncher() {
    if launcherWindowController?.isVisible == true {
      hideLauncher()
    } else {
      showLauncher()
    }
  }

  func hideLauncher() {
    guard let launcherWindowController else {
      return
    }

    self.launcherWindowController = nil
    launcherWindowController.hide()
  }

  func showLauncher() {
    launcherController().show()
  }

  private func handleHotKey(_ action: HotKeyAction) {
    switch action {
    case .launcher:
      toggleLauncher()
    case .shortcuts:
      launcherController().toggle(mode: .shortcuts)
    case .emoji:
      launcherController().toggle(mode: .emoji)
    case .files:
      launcherController().toggle(mode: .files)
    }
  }

  private func launcherController() -> LauncherWindowController {
    if let launcherWindowController {
      return launcherWindowController
    }

    let launcherWindowController = LauncherWindowController(
      store: store,
      settingsStore: settingsStore,
      hotKeyStore: hotKeyStore,
      onHide: { [weak self] in
        self?.hideLauncher()
      },
      onOpenSettings: { [weak self] in
        self?.showSettingsFromLauncher()
      }
    )
    self.launcherWindowController = launcherWindowController

    return launcherWindowController
  }

  private func showSettingsFromLauncher() {
    showSettings()
    hideLauncher()
  }

  private func showSettings() {
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        store: settingsStore,
        hotKeyStore: hotKeyStore,
        currencyRateStore: currencyRateStore,
        launchAtLoginStore: launchAtLoginStore,
        onClose: { [weak self] in
          self?.settingsWindowController = nil
        }
      )
    }

    settingsWindowController?.show()
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
    showSettings()
  }

  @objc private func quitFromMenu() {
    NSApp.terminate(nil)
  }

  private func observeVolumeChanges() {
    let notificationCenter = NSWorkspace.shared.notificationCenter
    let notificationNames: [Notification.Name] = [
      NSWorkspace.didMountNotification,
      NSWorkspace.didUnmountNotification,
    ]

    volumeObservers = notificationNames.map { name in
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
    catalogRefresh.schedule { [weak self] in
      self?.applicationDirectoryMonitor.start(
        directories: ApplicationCatalog.applicationDirectories()
      )
      self?.store.loadApplications()
    }
  }
}

@MainActor
private final class Debouncer {
  private let delay: TimeInterval
  private var workItem: DispatchWorkItem?

  init(delay: TimeInterval) {
    self.delay = delay
  }

  func schedule(_ action: @escaping @MainActor () -> Void) {
    cancel()
    let workItem = DispatchWorkItem { action() }
    self.workItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  func cancel() {
    workItem?.cancel()
    workItem = nil
  }
}

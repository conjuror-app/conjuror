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

      self?.hideLauncher(restoringFocus: event.restoresPreviousFocus)
    }
  )

  private lazy var currencyRateStore = CurrencyRateStore()
  private lazy var launchAtLoginStore = LaunchAtLoginStore()

  private lazy var hotKeyStore = HotKeyStore(
    settingsStore: settingsStore,
    onHotKeyPressed: { [weak self] target in
      Task { @MainActor [weak self] in
        self?.handleHotKey(target)
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
    observeApplicationCatalog()
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
      hideLauncher(restoringFocus: true)
    } else {
      showLauncher()
    }
  }

  func hideLauncher(restoringFocus: Bool = false) {
    guard let launcherWindowController else {
      return
    }

    self.launcherWindowController = nil
    launcherWindowController.hide(restoringFocus: restoringFocus)
    store.didHide()
  }

  func showLauncher() {
    launcherController().show()
  }

  private func handleHotKey(_ target: HotKeyTarget) {
    switch target {
    case .action(let action):
      handleHotKey(action)
    case .application(let path):
      hideLauncher()
      Task {
        do {
          try await ApplicationActivator().toggle(path: path)
        } catch {
          NSSound.beep()
        }
      }
    }
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
      onHide: { [weak self] restoringFocus in
        self?.hideLauncher(restoringFocus: restoringFocus)
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
        launcherStore: store,
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
      let configuration = NSImage.SymbolConfiguration(
        pointSize: 14,
        weight: .semibold
      ).applying(.preferringMonochrome())
      let image = NSImage(
        systemSymbolName: "wand.and.stars",
        accessibilityDescription: "Conjuror"
      )?.withSymbolConfiguration(configuration)
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
        self?.store.setCurrencyRates(isEnabled ? rates : nil)
      }
      .store(in: &cancellables)
  }

  /// Follows customized apps that moved, then re-registers hot keys for their new paths.
  private func observeApplicationCatalog() {
    store.$applications
      .dropFirst()
      .sink { [weak self] applications in
        guard let self, !applications.isEmpty,
          settingsStore.relocateApplicationCustomizations(installed: applications)
        else { return }

        hotKeyStore.register()
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

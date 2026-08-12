import AppKit
import Testing

@testable import Conjuror

@MainActor
@Suite("Launcher Store")
struct LauncherStoreTests {
  @Test("Launcher store: filtered applications update when the query changes")
  func testFilteredApplicationsUpdateWhenQueryChanges() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = LauncherStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)

    #expect(store.filteredApplications == applications)

    store.query = "beta"

    #expect(store.filteredApplications == [applications[1]])
    #expect(store.selectedApplicationID == applications[1].id)
  }

  @Test("Launcher store: preferred skin tone replaces tone-capable base emoji")
  func testPreferredSkinToneReplacesToneCapableBaseEmoji() {
    let settings = SettingsStore(userDefaults: makeUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = LauncherStore(
      settingsStore: settings,
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(":waving hand")

    #expect(store.displayedEmoji.first?.value == "👋🏾")
    #expect(!(store.displayedEmoji.contains { $0.value == "👋" }))
  }

  @Test("Launcher store: preferred skin tone replaces gendered couple emoji")
  func testPreferredSkinToneReplacesGenderedCoupleEmoji() {
    let settings = SettingsStore(userDefaults: makeUserDefaults())
    settings.setPreferredEmojiSkinTone(.mediumDark)
    let store = LauncherStore(
      settingsStore: settings,
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(":kiss woman man")

    #expect(store.displayedEmoji.first?.value == "👩🏾‍❤️‍💋‍👨🏾")
    #expect(!(store.displayedEmoji.contains { $0.value == "👩‍❤️‍💋‍👨" }))
  }

  @Test("Launcher store: greater-than switches to shortcuts and filters following text")
  func testGreaterThanSwitchesToShortcutsAndFiltersFollowingText() async {
    let shortcuts = [
      shortcut("Morning Lights", id: "morning"),
      shortcut("Evening Lights", id: "evening"),
    ]
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: shortcuts),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(">evening")
    await waitForShortcutsLoadingToFinish(store)

    #expect(store.mode == .shortcuts)
    #expect(store.query == "evening")
    #expect(store.filteredShortcuts == [shortcuts[1]])
    #expect(store.selectedShortcutID == shortcuts[1].id)
  }

  @Test("Launcher store: colon switches to emoji and filters following text")
  func testColonSwitchesToEmojiAndFiltersFollowingText() {
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(":waving hand medium dark")

    #expect(store.mode == .emoji)
    #expect(store.query == "waving hand medium dark")
    #expect(store.filteredEmoji.first?.value == "👋🏾")
  }

  @Test("Launcher store: Tab mode cycling visits shortcuts, emoji, and applications")
  func testTabModeCycleVisitsShortcutsEmojiAndApplications() {
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: []),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )

    store.cycleMode()
    #expect(store.mode == .shortcuts)

    store.cycleMode()
    #expect(store.mode == .emoji)

    store.cycleMode()
    #expect(store.mode == .applications)
  }

  @Test("Launcher store: calculator does not evaluate in shortcuts mode")
  func testCalculatorDoesNotEvaluateInShortcutsMode() {
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: []),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(">2 + 3")

    #expect(store.mode == .shortcuts)
    #expect((store.calculatorResult) == nil)
    #expect(!(store.isCalculatorSelected))
  }

  @Test("Launcher store: active loads run one follow-up refresh for a load request")
  func testLoadRequestDuringActiveLoadRunsOneFollowUpRefresh() async {
    let firstApplications = [application("Alpha", id: "dev.example.alpha")]
    let refreshedApplications = [application("Beta", id: "dev.example.beta")]
    let catalog = ControlledCatalog()
    let store = LauncherStore(
      catalog: catalog,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(
        userDefaults: makeUserDefaults()
      )
    )

    store.loadApplications()
    await catalog.waitForLoadCount(1)

    store.loadApplications()
    store.loadApplications()
    catalog.resumeNext(returning: firstApplications)
    await catalog.waitForLoadCount(2)

    #expect(store.isLoading)
    catalog.resumeNext(returning: refreshedApplications)
    while store.isLoading {
      await Task.yield()
    }

    let loadCount = catalog.loadCount
    #expect(loadCount == 2)
    #expect(store.applications == refreshedApplications)
    #expect(store.selectedApplicationID == refreshedApplications[0].id)
  }

  @Test("Launcher store: successful launches refresh recent application order")
  func testSuccessfulLaunchRefreshesRecentApplicationOrder() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    var didLaunch = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      onLaunchSuccess: { didLaunch = true }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)

    store.open(applications[1])
    while !didLaunch {
      await Task.yield()
    }

    #expect(store.filteredApplications == [applications[1], applications[0]])
    #expect(store.selectedApplicationID == applications[1].id)
  }

  @Test("Launcher store: catalog failures publish errors and clear selection")
  func testCatalogFailurePublishesErrorAndClearsSelection() async {
    let store = LauncherStore(
      catalog: FailingCatalogStub(),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )

    store.loadApplications()
    await waitForLoadingToFinish(store)

    #expect(store.applications.isEmpty)
    #expect((store.selectedApplicationID) == nil)
    #expect(
      store.catalogErrorMessage == "Couldn’t load installed applications. Catalog unavailable"
    )
  }

  @Test("Launcher store: calculator results are pinned before matching applications")
  func testCalculatorResultIsPinnedBeforeMatchingApplications() async {
    let application = application("Pine", id: "dev.example.pine")
    let store = LauncherStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)

    store.query = "pi"

    #expect(store.calculatorResult?.expression == "pi")
    #expect(store.isCalculatorSelected)
    #expect(store.selectedResultScrollID == LauncherStore.calculatorResultScrollID)
    #expect(store.filteredApplications == [application])

    store.moveSelection(.down)
    #expect(!(store.isCalculatorSelected))
    #expect(store.selectedApplicationID == application.id)

    store.moveSelection(.up)
    #expect(store.isCalculatorSelected)
  }

  @Test("Launcher store: arrow navigation moves selection down and up")
  func testArrowNavigationMovesSelectionDownAndUp() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
      application("Gamma", id: "dev.example.gamma"),
    ]
    let store = LauncherStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(
        userDefaults: makeUserDefaults()
      )
    )

    store.loadApplications()
    await waitForLoadingToFinish(store)

    #expect(store.selectedApplicationID == applications[0].id)

    let scrollRequestAfterLoad = store.selectionScrollRequest
    store.select(applications[1])
    #expect(store.selectionScrollRequest == scrollRequestAfterLoad)
    store.select(applications[0])

    store.moveSelection(.down)
    #expect(store.selectionScrollRequest != scrollRequestAfterLoad)
    #expect(store.selectedApplicationID == applications[1].id)

    store.moveSelection(.up)
    #expect(store.selectedApplicationID == applications[0].id)
  }

  @Test("Launcher store: horizontal arrows navigate the emoji grid")
  func testHorizontalArrowsNavigateEmojiGrid() {
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )
    store.updateQuery(":")
    let firstID = store.selectedEmojiID

    store.moveSelection(.right)
    #expect(store.selectedEmojiID == store.displayedEmoji[1].id)

    store.moveSelection(.left)
    #expect(store.selectedEmojiID == firstID)
  }

  @Test("Launcher store: successful launches record history, clear the query, and call success")
  func testSuccessfulLaunchRecordsHistoryClearsQueryAndCallsSuccess() async {
    let application = application("Alpha", id: "dev.example.alpha")
    let userDefaults = makeUserDefaults()
    let launchHistory = LaunchHistoryStore(userDefaults: userDefaults)
    var didLaunch = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(),
      launchHistory: launchHistory,
      onLaunchSuccess: { didLaunch = true }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"

    store.openSelectedApplication()
    while !didLaunch {
      await Task.yield()
    }

    #expect(store.query == "")
    #expect((store.launchErrorMessage) == nil)
    #expect((launchHistory.load()[application.persistenceKey]) != nil)
  }

  @Test("Launcher store: failed launches preserve the query and skip history")
  func testFailedLaunchPreservesQueryAndDoesNotRecordHistory() async {
    let application = application("Alpha", id: "dev.example.alpha")
    let launchHistory = LaunchHistoryStore(userDefaults: makeUserDefaults())
    var didLaunch = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(error: TestError.launchFailed),
      launchHistory: launchHistory,
      onLaunchSuccess: { didLaunch = true }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"

    store.openSelectedApplication()
    while store.launchErrorMessage == nil {
      await Task.yield()
    }

    #expect(store.query == "alpha")
    #expect(store.launchErrorMessage == "Couldn’t open Alpha. Launch failed")
    #expect(!(didLaunch))
    #expect(launchHistory.load().isEmpty)
  }

  @Test("Launcher store: Return copies calculator results, clears the query, and requests hiding")
  func testReturnCopiesCalculatorResultClearsQueryAndRequestsHide() {
    let clipboard = RecordingCalculatorClipboard()
    var didRequestHide = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      onCalculatorResultCopied: { didRequestHide = true }
    )
    store.query = "2 + 3"

    store.openSelectedResult()

    #expect(clipboard.text == "5")
    #expect(didRequestHide)
    #expect(store.query == "")
    #expect((store.calculatorResult) == nil)
  }

  @Test("Launcher store: Return copies quantity results with their units")
  func testReturnCopiesQuantityResultWithUnit() {
    let clipboard = RecordingCalculatorClipboard()
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )
    store.query = "1000 m to km"

    store.openSelectedResult()

    #expect(clipboard.text == "1 km")
    #expect(store.query == "")
  }

  @Test("Launcher store: Return copies emoji and records it as recent")
  func testReturnCopiesEmojiAndRecordsItAsRecent() {
    let clipboard = RecordingCalculatorClipboard()
    let userDefaults = makeUserDefaults()
    let history = EmojiHistoryStore(userDefaults: userDefaults)
    var didRequestHide = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: history,
      onEmojiCopied: { didRequestHide = true }
    )
    store.updateQuery(":face with tears of joy")

    store.openSelectedResult()

    #expect(clipboard.text == "😂")
    #expect(history.load().first == "😂")
    #expect(didRequestHide)
    #expect(store.mode == .applications)
  }

  @Test("Launcher store: Return runs the selected fuzzy shortcut")
  func testReturnRunsTheSelectedFuzzyShortcut() async {
    let mainBedroom = shortcut("Main Bedroom", id: "main")
    let guestBedroom = shortcut("Guest Bedroom", id: "guest")
    let runner = RecordingShortcutRunner()
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(
        shortcuts: [mainBedroom, guestBedroom]
      ),
      shortcutRunner: runner,
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    )
    store.updateQuery(">bedroom")
    await waitForShortcutsLoadingToFinish(store)
    store.select(mainBedroom)

    store.openSelectedResult()
    while runner.lastRunShortcut == nil {
      await Task.yield()
    }

    #expect(runner.lastRunShortcut == mainBedroom)
  }

  @Test("Launcher store: running shortcuts hide immediately and record successful runs")
  func testRunningShortcutHidesImmediatelyAndRecordsSuccessfulRun() async {
    let shortcut = shortcut("Lights", id: "lights")
    let history = ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    var didRequestHide = false
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: [shortcut]),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: history,
      onShortcutRunStarted: { didRequestHide = true }
    )
    store.enterShortcutsMode()
    await waitForShortcutsLoadingToFinish(store)

    store.runSelectedShortcut()

    #expect(didRequestHide)
    while history.load()[shortcut.persistenceKey] == nil {
      await Task.yield()
    }
    #expect((store.shortcutRunErrorMessage) == nil)
  }

  @Test("Launcher store: failed shortcut runs appear in shortcut mode on next activation")
  func testFailedShortcutRunIsShownInShortcutModeOnNextActivation() async {
    let shortcut = shortcut("Lights", id: "lights")
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: [shortcut]),
      shortcutRunner: ShortcutRunnerStub(error: TestError.launchFailed),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeUserDefaults())
    )
    store.updateQuery(">light")
    await waitForShortcutsLoadingToFinish(store)

    store.runSelectedShortcut()
    while store.shortcutRunErrorMessage == nil {
      await Task.yield()
    }
    store.prepareForActivation()

    #expect(store.mode == .shortcuts)
    #expect(store.query == "light")
    #expect(store.shortcutRunErrorMessage == "Couldn’t run Lights. Launch failed")
  }

  @Test("Launcher store: activation clears transient state and selects the first result")
  func testPrepareForActivationClearsTransientStateAndSelectsFirstResult() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = LauncherStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(error: TestError.launchFailed),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "beta"
    store.openSelectedApplication()
    while store.launchErrorMessage == nil {
      await Task.yield()
    }
    let focusRequest = store.focusRequest

    store.prepareForActivation()

    #expect(store.query == "")
    #expect((store.launchErrorMessage) == nil)
    #expect(store.selectedApplicationID == applications[0].id)
    #expect(store.focusRequest != focusRequest)
  }

  private func shortcut(_ name: String, id: String) -> AppleShortcut {
    AppleShortcut(id: id, name: name, subtitle: "", acceptsInput: false)
  }

  private func application(_ name: String, id: String) -> InstalledApplication {
    InstalledApplication(
      displayName: name,
      bundleIdentifier: id,
      url: URL(fileURLWithPath: "/Applications/\(name).app"),
      icon: NSImage(size: NSSize(width: 32, height: 32))
    )
  }

  private func makeUserDefaults() -> UserDefaults {
    let suiteName = "LauncherStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
  }

  private func waitForLoadingToFinish(_ store: LauncherStore) async {
    while store.isLoading {
      await Task.yield()
    }
  }

  private func waitForShortcutsLoadingToFinish(_ store: LauncherStore) async {
    while store.isLoadingShortcuts {
      await Task.yield()
    }
  }
}

private struct CatalogStub: ApplicationCatalogLoading {
  let applications: [InstalledApplication]

  func load() async throws -> [InstalledApplication] {
    applications
  }
}

private struct FailingCatalogStub: ApplicationCatalogLoading {
  func load() async throws -> [InstalledApplication] {
    throw TestError.catalogUnavailable
  }
}

private struct ShortcutCatalogStub: ShortcutCatalogLoading {
  let shortcuts: [AppleShortcut]

  func load() async throws -> [AppleShortcut] {
    shortcuts
  }
}

private struct ShortcutRunnerStub: ShortcutRunning {
  var error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func run(_ shortcut: AppleShortcut) async throws {
    if let error {
      throw error
    }
  }
}

@MainActor
private final class RecordingShortcutRunner: ShortcutRunning {
  private(set) var lastRunShortcut: AppleShortcut?

  func run(_ shortcut: AppleShortcut) async throws {
    lastRunShortcut = shortcut
  }
}

@MainActor
private final class RecordingCalculatorClipboard: CalculatorClipboardWriting {
  private(set) var text: String?

  func write(_ text: String) {
    self.text = text
  }
}

private struct LauncherStub: ApplicationLaunching {
  var error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func open(_ application: InstalledApplication) async throws {
    if let error {
      throw error
    }
  }
}

@MainActor
private final class ControlledCatalog: ApplicationCatalogLoading {
  private(set) var loadCount = 0
  private var continuations = [CheckedContinuation<[InstalledApplication], Error>]()

  func load() async throws -> [InstalledApplication] {
    loadCount += 1
    return try await withCheckedThrowingContinuation { continuation in
      continuations.append(continuation)
    }
  }

  func resumeNext(returning applications: [InstalledApplication]) {
    continuations.removeFirst().resume(returning: applications)
  }

  func waitForLoadCount(_ expectedCount: Int) async {
    while loadCount < expectedCount {
      await Task.yield()
    }
  }
}

private enum TestError: LocalizedError {
  case catalogUnavailable
  case launchFailed

  var errorDescription: String? {
    switch self {
    case .catalogUnavailable:
      return "Catalog unavailable"
    case .launchFailed:
      return "Launch failed"
    }
  }
}

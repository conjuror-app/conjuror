import AppKit
import XCTest

@testable import Conjuror

@MainActor
final class LauncherStoreTests: XCTestCase {
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

    XCTAssertEqual(store.selectedApplicationID, applications[0].id)

    let scrollRequestAfterLoad = store.selectionScrollRequest
    store.select(applications[1])
    XCTAssertEqual(store.selectionScrollRequest, scrollRequestAfterLoad)
    store.select(applications[0])

    store.moveSelection(.down)
    XCTAssertNotEqual(store.selectionScrollRequest, scrollRequestAfterLoad)
    XCTAssertEqual(store.selectedApplicationID, applications[1].id)

    store.moveSelection(.up)
    XCTAssertEqual(store.selectedApplicationID, applications[0].id)
  }

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

    XCTAssertEqual(store.filteredApplications, applications)

    store.query = "beta"

    XCTAssertEqual(store.filteredApplications, [applications[1]])
    XCTAssertEqual(store.selectedApplicationID, applications[1].id)
  }

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

    XCTAssertEqual(store.filteredApplications, [applications[1], applications[0]])
    XCTAssertEqual(store.selectedApplicationID, applications[1].id)
  }

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

    XCTAssertTrue(store.isLoading)
    catalog.resumeNext(returning: refreshedApplications)
    while store.isLoading {
      await Task.yield()
    }

    let loadCount = catalog.loadCount
    XCTAssertEqual(loadCount, 2)
    XCTAssertEqual(store.applications, refreshedApplications)
    XCTAssertEqual(store.selectedApplicationID, refreshedApplications[0].id)
  }

  func testCatalogFailurePublishesErrorAndClearsSelection() async {
    let store = LauncherStore(
      catalog: FailingCatalogStub(),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults())
    )

    store.loadApplications()
    await waitForLoadingToFinish(store)

    XCTAssertTrue(store.applications.isEmpty)
    XCTAssertNil(store.selectedApplicationID)
    XCTAssertEqual(
      store.catalogErrorMessage,
      "Couldn’t load installed applications. Catalog unavailable"
    )
  }

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

    XCTAssertEqual(store.query, "")
    XCTAssertNil(store.launchErrorMessage)
    XCTAssertNotNil(launchHistory.load()[application.persistenceKey])
  }

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

    XCTAssertEqual(store.query, "alpha")
    XCTAssertEqual(
      store.launchErrorMessage,
      "Couldn’t open Alpha. Launch failed"
    )
    XCTAssertFalse(didLaunch)
    XCTAssertTrue(launchHistory.load().isEmpty)
  }

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

    XCTAssertEqual(store.query, "")
    XCTAssertNil(store.launchErrorMessage)
    XCTAssertEqual(store.selectedApplicationID, applications[0].id)
    XCTAssertNotEqual(store.focusRequest, focusRequest)
  }

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

    XCTAssertEqual(store.mode, .shortcuts)
    XCTAssertEqual(store.query, "evening")
    XCTAssertEqual(store.filteredShortcuts, [shortcuts[1]])
    XCTAssertEqual(store.selectedShortcutID, shortcuts[1].id)
  }

  func testColonSwitchesToEmojiAndFiltersFollowingText() {
    let store = LauncherStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeUserDefaults()),
      emojiHistory: EmojiHistoryStore(userDefaults: makeUserDefaults())
    )

    store.updateQuery(":waving hand medium dark")

    XCTAssertEqual(store.mode, .emoji)
    XCTAssertEqual(store.query, "waving hand medium dark")
    XCTAssertEqual(store.filteredEmoji.first?.value, "👋🏾")
  }

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

    XCTAssertEqual(store.displayedEmoji.first?.value, "👋🏾")
    XCTAssertFalse(store.displayedEmoji.contains { $0.value == "👋" })
  }

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

    XCTAssertEqual(store.displayedEmoji.first?.value, "👩🏾‍❤️‍💋‍👨🏾")
    XCTAssertFalse(store.displayedEmoji.contains { $0.value == "👩‍❤️‍💋‍👨" })
  }

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
    XCTAssertEqual(store.selectedEmojiID, store.displayedEmoji[1].id)

    store.moveSelection(.left)
    XCTAssertEqual(store.selectedEmojiID, firstID)
  }

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

    XCTAssertEqual(clipboard.text, "😂")
    XCTAssertEqual(history.load().first, "😂")
    XCTAssertTrue(didRequestHide)
    XCTAssertEqual(store.mode, .applications)
  }

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

    XCTAssertEqual(store.calculatorResult?.expression, "pi")
    XCTAssertTrue(store.isCalculatorSelected)
    XCTAssertEqual(store.selectedResultScrollID, LauncherStore.calculatorResultScrollID)
    XCTAssertEqual(store.filteredApplications, [application])

    store.moveSelection(.down)
    XCTAssertFalse(store.isCalculatorSelected)
    XCTAssertEqual(store.selectedApplicationID, application.id)

    store.moveSelection(.up)
    XCTAssertTrue(store.isCalculatorSelected)
  }

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

    XCTAssertEqual(clipboard.text, "5")
    XCTAssertTrue(didRequestHide)
    XCTAssertEqual(store.query, "")
    XCTAssertNil(store.calculatorResult)
  }

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

    XCTAssertEqual(clipboard.text, "1 km")
    XCTAssertEqual(store.query, "")
  }

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

    XCTAssertEqual(store.mode, .shortcuts)
    XCTAssertNil(store.calculatorResult)
    XCTAssertFalse(store.isCalculatorSelected)
  }

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

    XCTAssertEqual(runner.lastRunShortcut, mainBedroom)
  }

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

    XCTAssertTrue(didRequestHide)
    while history.load()[shortcut.persistenceKey] == nil {
      await Task.yield()
    }
    XCTAssertNil(store.shortcutRunErrorMessage)
  }

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

    XCTAssertEqual(store.mode, .shortcuts)
    XCTAssertEqual(store.query, "light")
    XCTAssertEqual(
      store.shortcutRunErrorMessage,
      "Couldn’t run Lights. Launch failed"
    )
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

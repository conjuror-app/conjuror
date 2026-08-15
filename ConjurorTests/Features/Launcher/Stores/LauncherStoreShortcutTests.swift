import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Launcher store: greater-than switches to shortcuts and filters following text")
  func testGreaterThanSwitchesToShortcutsAndFiltersFollowingText() async {
    let shortcuts = [
      shortcut("Morning Lights", id: "morning"),
      shortcut("Evening Lights", id: "evening"),
    ]
    let store = makeStore(shortcuts: shortcuts)

    store.updateQuery(">evening")
    await waitForShortcutsLoadingToFinish(store)

    #expect(store.mode == .shortcuts)
    #expect(store.query == "evening")
    #expect(store.filteredShortcuts == [shortcuts[1]])
    #expect(store.selectedShortcutID == shortcuts[1].id)
  }

  @Test("Launcher store: Return runs the selected fuzzy shortcut")
  func testReturnRunsTheSelectedFuzzyShortcut() async {
    let mainBedroom = shortcut("Main Bedroom", id: "main")
    let guestBedroom = shortcut("Guest Bedroom", id: "guest")
    let runner = RecordingShortcutRunner()
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(
        shortcuts: [mainBedroom, guestBedroom]
      ),
      shortcutRunner: runner,
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults())
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
    let history = ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults())
    var didRequestHide = false
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: [shortcut]),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: history,
      onEvent: { if $0 == .shortcutRunStarted { didRequestHide = true } }
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
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: [shortcut]),
      shortcutRunner: ShortcutRunnerStub(error: TestError.launchFailed),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults())
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
}

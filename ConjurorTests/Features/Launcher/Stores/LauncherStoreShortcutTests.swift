import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Greater-than switches to shortcuts and filters following text")
  func testShortcutPrefix() async {
    let shortcuts = [
      shortcut("Morning Lights", id: "morning"),
      shortcut("Evening Lights", id: "evening"),
    ]
    let store = makeStore(shortcuts: shortcuts)

    store.updateQuery(">evening")
    await waitForShortcuts(store)

    #expect(store.mode == .shortcuts)
    #expect(store.query == "evening")
    #expect(store.filteredShortcuts == [shortcuts[1]])
    #expect(store.selectedResultID == .shortcut(shortcuts[1].id))
  }

  @Test("Launcher store: Return runs the selected fuzzy shortcut")
  func testReturnRunsTheSelectedFuzzyShortcut() async {
    let mainBedroom = shortcut("Main Bedroom", id: "main")
    let guestBedroom = shortcut("Guest Bedroom", id: "guest")
    let runner = RecordingShortcutRunner()
    let store = makeStore(
      shortcutCatalog: ShortcutCatalogStub(
        shortcuts: [mainBedroom, guestBedroom]
      ),
      runShortcut: runner.run,
    )
    store.updateQuery(">bedroom")
    await waitForShortcuts(store)
    store.select(.shortcut(mainBedroom.id))

    store.openSelectedResult()

    while runner.lastRunShortcut == nil {
      await Task.yield()
    }

    #expect(runner.lastRunShortcut == mainBedroom)
  }

  @Test("Running shortcuts hide immediately and record successful runs")
  func testSuccessfulShortcutRun() async {
    let shortcut = shortcut("Lights", id: "lights")
    let history = RecencyStore.shortcutRuns(userDefaults: makeTestUserDefaults())
    var didRequestHide = false
    let store = makeStore(
      shortcuts: [shortcut],
      shortcutRunHistory: history,
      onEvent: { if $0 == .shortcutRunStarted { didRequestHide = true } }
    )
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    store.openSelectedResult()

    #expect(didRequestHide)
    while history.load()[shortcut.persistenceKey] == nil {
      await Task.yield()
    }

    #expect(store.actionErrorMessage == nil)
  }

  @Test("A cancelled shortcut can run again")
  func testCancelledShortcutCanRunAgain() async {
    let shortcut = shortcut("Lights", id: "lights")
    var attempts = 0
    let store = makeStore(
      shortcuts: [shortcut],
      runShortcut: { _ in
        attempts += 1
        if attempts == 1 { throw CancellationError() }
      }
    )
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    let deadline = ContinuousClock.now + .seconds(10)
    while attempts < 2, ContinuousClock.now < deadline {
      store.openSelectedResult()
      await Task.yield()
    }

    #expect(attempts == 2)
    #expect(store.actionErrorMessage == nil)
  }

  @Test("Failed shortcut runs appear in shortcut mode on next activation")
  func testFailedShortcutRun() async {
    let shortcut = shortcut("Lights", id: "lights")
    let store = makeStore(
      shortcuts: [shortcut],
      runShortcut: ShortcutRunnerStub(error: TestError.launchFailed).run,
    )
    store.updateQuery(">light")
    await waitForShortcuts(store)

    store.openSelectedResult()

    while store.actionErrorMessage == nil {
      await Task.yield()
    }

    store.prepareForActivation()

    #expect(store.mode == .shortcuts)
    #expect(store.query == "light")
    #expect(store.actionErrorMessage == "Couldn’t run Lights. Launch failed")
  }

  @Test("Cached shortcuts show first and are replaced by the current shortcuts")
  func testCachedShortcutsAreRefreshed() async {
    let lights = shortcut("Lights", id: "lights")
    let fans = shortcut("Fans", id: "fans")
    let catalog = MutableShortcutCatalog(cached: [lights], current: [lights, fans])
    let store = makeStore(shortcutCatalog: catalog)

    store.prepareForActivation(mode: .shortcuts)

    #expect(store.shortcuts == [lights])
    await waitForShortcuts(store)
    #expect(Set(store.filteredShortcuts) == [lights, fans])
  }

  @Test("Reopening shortcuts mode picks up new shortcuts")
  func testReopeningShortcutsModeRefreshes() async {
    let lights = shortcut("Lights", id: "lights")
    let fans = shortcut("Fans", id: "fans")
    let catalog = MutableShortcutCatalog(current: [lights])
    let store = makeStore(shortcutCatalog: catalog)
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    catalog.current = [lights, fans]
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    #expect(Set(store.filteredShortcuts) == [lights, fans])
  }

  @Test("A failed refresh keeps the shortcuts already shown")
  func testFailedRefreshKeepsShortcuts() async {
    let lights = shortcut("Lights", id: "lights")
    let catalog = MutableShortcutCatalog(current: [lights])
    let store = makeStore(shortcutCatalog: catalog)
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    catalog.error = TestError.launchFailed
    store.prepareForActivation(mode: .shortcuts)
    await waitForShortcuts(store)

    #expect(store.filteredShortcuts == [lights])
    #expect(store.shortcutCatalogErrorMessage == nil)
  }
}

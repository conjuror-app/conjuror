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
    #expect(store.selectedShortcutID == shortcuts[1].id)
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
    store.select(mainBedroom)

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

    #expect(store.shortcutRunErrorMessage == nil)
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

    while store.shortcutRunErrorMessage == nil {
      await Task.yield()
    }

    store.prepareForActivation()

    #expect(store.mode == .shortcuts)
    #expect(store.query == "light")
    #expect(store.shortcutRunErrorMessage == "Couldn’t run Lights. Launch failed")
  }
}

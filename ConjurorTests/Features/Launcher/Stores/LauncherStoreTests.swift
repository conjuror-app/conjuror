import AppKit
import Testing

@testable import Conjuror

@MainActor
@Suite("Launcher Store")
struct LauncherStoreTests {

  @Test("Launcher store: mode prefixes switch between all modes")
  func testModePrefixesSwitchBetweenAllModes() async {
    let store = makeStore()

    store.updateQuery(":")
    #expect(store.mode == .emoji)

    store.updateQuery(">")
    await waitForShortcutsLoadingToFinish(store)
    #expect(store.mode == .shortcuts)

    store.updateQuery("/notes")
    #expect(store.mode == .files)

    store.updateQuery(";conjuror")
    #expect(store.mode == .applications)
    #expect(store.query == "conjuror")
  }

  @Test("Launcher store: slash switches to files and publishes search results")
  func testSlashSwitchesToFilesAndSearches() async {
    let result = FileSearchResult(
      url: URL(fileURLWithPath: "/Users/example/Documents/Notes.txt"),
      displayName: "Notes.txt",
      isDirectory: false,
      modificationDate: nil
    )
    let store = makeStore(fileSearcher: FileSearcherStub(results: [result]))

    store.updateQuery("/notes")
    while store.isSearchingFiles {
      try? await Task.sleep(for: .milliseconds(10))
    }

    #expect(store.mode == .files)
    #expect(store.query == "notes")
    #expect(store.fileResults == [result])
    #expect(store.selectedFileID == result.id)
  }

  @Test("Launcher store: Tab mode cycling visits shortcuts, emoji, files, and applications")
  func testTabModeCycleVisitsShortcutsEmojiFilesAndApplications() {
    let store = makeStore()

    store.cycleMode()
    #expect(store.mode == .shortcuts)

    store.cycleMode()
    #expect(store.mode == .emoji)

    store.cycleMode()
    #expect(store.mode == .files)

    store.cycleMode()
    #expect(store.mode == .applications)
  }

  @Test("Launcher store: calculator does not evaluate in shortcuts mode")
  func testCalculatorDoesNotEvaluateInShortcutsMode() {
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: ShortcutCatalogStub(shortcuts: []),
      shortcutRunner: ShortcutRunnerStub(),
      shortcutRunHistory: ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults())
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
    let store = makeStore(
      catalog: catalog,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(
        userDefaults: makeTestUserDefaults()
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

  @Test("Launcher store: calculator results are pinned before matching applications")
  func testCalculatorResultIsPinnedBeforeMatchingApplications() async {
    let application = application("Pine", id: "dev.example.pine")
    let store = makeStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults())
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)

    store.query = "pi"

    #expect(store.calculatorResult?.expression == "pi")
    #expect(store.isCalculatorSelected)
    #expect(store.selectedResultScrollID == .calculator)
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
    let store = makeStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(
        userDefaults: makeTestUserDefaults()
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

  @Test("Launcher store: Return copies calculator results, clears the query, and requests hiding")
  func testReturnCopiesCalculatorResultClearsQueryAndRequestsHide() {
    let clipboard = RecordingCalculatorClipboard()
    var didRequestHide = false
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      onEvent: { if $0 == .calculatorResultCopied { didRequestHide = true } }
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
    let store = makeStore(
      catalog: CatalogStub(applications: []),
      calculatorClipboard: clipboard,
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults())
    )
    store.query = "1000 m to km"

    store.openSelectedResult()

    #expect(clipboard.text == "1 km")
    #expect(store.query == "")
  }

  func makeStore(
    applications: [InstalledApplication] = [],
    shortcuts: [AppleShortcut] = [],
    settingsStore: SettingsStore? = nil,
    catalog: ApplicationCatalogLoading? = nil,
    calculator: CalculatorEvaluating = CalculatorEngine(),
    calculatorClipboard: CalculatorClipboardWriting = SystemCalculatorClipboard(),
    launcher: ApplicationLaunching = LauncherStub(),
    launchHistory: LaunchHistoryStore? = nil,
    shortcutCatalog: ShortcutCatalogLoading? = nil,
    shortcutRunner: ShortcutRunning = ShortcutRunnerStub(),
    shortcutRunHistory: ShortcutRunHistoryStore? = nil,
    emojiHistory: EmojiHistoryStore? = nil,
    fileSearcher: FileSearching = FileSearcherStub(results: []),
    fileOpener: FileOpening = FileOpener(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) -> LauncherStore {
    LauncherStore(
      settingsStore: settingsStore ?? SettingsStore(userDefaults: makeTestUserDefaults()),
      catalog: catalog ?? CatalogStub(applications: applications),
      calculator: calculator,
      calculatorClipboard: calculatorClipboard,
      launcher: launcher,
      launchHistory: launchHistory ?? LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: shortcutCatalog ?? ShortcutCatalogStub(shortcuts: shortcuts),
      shortcutRunner: shortcutRunner,
      shortcutRunHistory: shortcutRunHistory
        ?? ShortcutRunHistoryStore(userDefaults: makeTestUserDefaults()),
      emojiHistory: emojiHistory ?? EmojiHistoryStore(userDefaults: makeTestUserDefaults()),
      fileSearcher: fileSearcher,
      fileOpener: fileOpener,
      onEvent: onEvent
    )
  }

  func shortcut(_ name: String, id: String) -> AppleShortcut {
    AppleShortcut(id: id, name: name, subtitle: "", acceptsInput: false)
  }

  func application(_ name: String, id: String) -> InstalledApplication {
    InstalledApplication(
      displayName: name,
      bundleIdentifier: id,
      url: URL(fileURLWithPath: "/Applications/\(name).app"),
      icon: NSImage(size: NSSize(width: 32, height: 32))
    )
  }

  func waitForLoadingToFinish(_ store: LauncherStore) async {
    while store.isLoading {
      await Task.yield()
    }
  }

  func waitForShortcutsLoadingToFinish(_ store: LauncherStore) async {
    while store.isLoadingShortcuts {
      await Task.yield()
    }
  }
}

struct CatalogStub: ApplicationCatalogLoading {
  let applications: [InstalledApplication]

  func load() async throws -> [InstalledApplication] {
    applications
  }
}

struct FileSearcherStub: FileSearching {
  let results: [FileSearchResult]

  func search(query: String) async throws -> [FileSearchResult] {
    results
  }
}

struct FailingCatalogStub: ApplicationCatalogLoading {
  func load() async throws -> [InstalledApplication] {
    throw TestError.catalogUnavailable
  }
}

struct ShortcutCatalogStub: ShortcutCatalogLoading {
  let shortcuts: [AppleShortcut]

  func load() async throws -> [AppleShortcut] {
    shortcuts
  }
}

struct ShortcutRunnerStub: ShortcutRunning {
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
final class RecordingShortcutRunner: ShortcutRunning {
  private(set) var lastRunShortcut: AppleShortcut?

  func run(_ shortcut: AppleShortcut) async throws {
    lastRunShortcut = shortcut
  }
}

@MainActor
final class RecordingCalculatorClipboard: CalculatorClipboardWriting {
  private(set) var text: String?

  func write(_ text: String) {
    self.text = text
  }
}

struct LauncherStub: ApplicationLaunching {
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

enum TestError: LocalizedError {
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

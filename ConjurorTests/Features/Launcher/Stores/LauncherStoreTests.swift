import AppKit
import Testing

@testable import Conjuror

@MainActor
@Suite("Launcher Store")
struct LauncherStoreTests {
  @Test("Mode prefixes switch between all modes")
  func testModePrefixesSwitchBetweenAllModes() async {
    let store = makeStore()

    store.updateQuery(":")
    #expect(store.mode == .emoji)

    store.updateQuery(">")
    await waitForShortcuts(store)
    #expect(store.mode == .shortcuts)

    store.updateQuery("/notes")
    #expect(store.mode == .files)

    store.updateQuery("!sleep")
    #expect(store.mode == .systemCommands)

    store.updateQuery("@safari")
    #expect(store.mode == .running)

    store.updateQuery(";conjuror")
    #expect(store.mode == .applications)
    #expect(store.query == "conjuror")
  }

  @Test("Slash switches to files and publishes search results")
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
    #expect(store.selectedResultID == .file(result.id))
  }

  @Test("Command-Return reveals the selected file")
  func testRevealSelectedFile() async {
    let result = FileSearchResult(
      url: URL(fileURLWithPath: "/Users/example/Documents/Notes.txt"),
      displayName: "Notes.txt",
      isDirectory: false,
      modificationDate: nil
    )
    var revealedURLs = [URL]()
    let store = makeStore(
      revealInFinder: { revealedURLs.append($0) },
      fileSearcher: FileSearcherStub(results: [result])
    )
    store.updateQuery("/notes")

    while store.isSearchingFiles {
      try? await Task.sleep(for: .milliseconds(10))
    }

    store.revealSelectedResult()

    #expect(revealedURLs == [result.url])
    #expect(store.query.isEmpty)
  }

  @Test("File search waits for two characters")
  func testFileSearchWaitsForTwoCharacters() async {
    let fileSearcher = RecordingFileSearcher()
    let store = makeStore(fileSearcher: fileSearcher)

    store.updateQuery("/n")
    await Task.yield()

    #expect(store.mode == .files)
    #expect(!store.isSearchingFiles)
    #expect(fileSearcher.queries.isEmpty)

    store.updateQuery("no")

    while store.isSearchingFiles {
      try? await Task.sleep(for: .milliseconds(10))
    }

    #expect(fileSearcher.queries == ["no"])
  }

  @Test("Disabled files module is skipped by prefixes and mode cycling")
  func testDisabledFilesModuleIsSkipped() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    settingsStore.setFilesModuleEnabled(false)
    let store = makeStore(settingsStore: settingsStore)

    store.updateQuery("/notes")
    #expect(store.mode == .applications)
    #expect(store.query == "/notes")

    store.updateQuery(":")
    #expect(store.mode == .emoji)
    store.cycleMode()
    #expect(store.mode == .running)

    store.prepareForActivation(mode: .files)
    #expect(store.mode == .applications)
  }

  @Test("Tab mode cycling visits every mode and returns to applications")
  func testModeCycle() {
    let store = makeStore()

    store.cycleMode()
    #expect(store.mode == .shortcuts)

    store.cycleMode()
    #expect(store.mode == .emoji)

    store.cycleMode()
    #expect(store.mode == .files)

    store.cycleMode()
    #expect(store.mode == .running)

    store.cycleMode()
    #expect(store.mode == .systemCommands)

    store.cycleMode()
    #expect(store.mode == .applications)
  }

  @Test("Calculator does not evaluate in shortcuts mode")
  func testNoCalculatorInShortcuts() {
    let store = makeStore()

    store.updateQuery(">2 + 3")

    #expect(store.mode == .shortcuts)
    #expect(store.calculatorResult == nil)
    #expect(!store.isCalculatorSelected)
  }

  @Test("Load requests share one follow-up refresh", arguments: [false, true])
  func testQueuedReload(cancelFirst: Bool) async {
    let firstApplications = [application("Alpha", id: "dev.example.alpha")]
    let refreshedApplications = [application("Beta", id: "dev.example.beta")]
    let catalog = ControlledCatalog()
    let store = makeStore(
      catalog: catalog,
    )

    store.loadApplications()
    await catalog.waitForLoadCount(1)

    store.loadApplications()
    store.loadApplications()

    if cancelFirst {
      catalog.cancelNext()
    } else {
      catalog.resumeNext(returning: firstApplications)
    }

    await catalog.waitForLoadCount(2)

    #expect(store.isLoading)
    catalog.resumeNext(returning: refreshedApplications)

    while store.isLoading {
      await Task.yield()
    }

    let loadCount = catalog.loadCount
    #expect(loadCount == 2)
    #expect(store.applications == refreshedApplications)
    #expect(store.selectedResultID == .application(refreshedApplications[0].id))
  }

  @Test("Calculator results are pinned before matching applications")
  func testCalculatorSelection() async {
    let application = application("Pine", id: "dev.example.pine")
    let store = makeStore(
      applications: [application],
    )
    store.loadApplications()
    await waitForApplications(store)

    store.query = "pi"

    #expect(store.calculatorResult?.expression == "pi")
    #expect(store.isCalculatorSelected)
    #expect(store.selectedResultID == .calculator)
    #expect(store.filteredApplications.first == application)

    store.moveSelection(.down)
    #expect(!store.isCalculatorSelected)
    #expect(store.selectedResultID == .application(application.id))

    store.moveSelection(.up)
    #expect(store.isCalculatorSelected)
  }

  @Test("Arrow navigation moves selection down and up")
  func testArrowSelection() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
      application("Gamma", id: "dev.example.gamma"),
    ]
    let store = makeStore(
      applications: applications,
    )

    store.loadApplications()
    await waitForApplications(store)

    #expect(store.selectedResultID == .application(applications[0].id))

    let scrollRequestAfterLoad = store.selectionScrollRequest
    store.select(.application(applications[1].id))
    #expect(store.selectionScrollRequest == scrollRequestAfterLoad)
    store.select(.application(applications[0].id))

    store.moveSelection(.down)
    #expect(store.selectionScrollRequest != scrollRequestAfterLoad)
    #expect(store.selectedResultID == .application(applications[1].id))

    store.moveSelection(.up)
    #expect(store.selectedResultID == .application(applications[0].id))
  }

  @Test("Launcher store: Return copies calculator results, clears the query, and requests hiding")
  func testCopyCalculation() {
    let clipboard = RecordingClipboard()
    var didRequestHide = false
    let store = makeStore(
      writeToClipboard: clipboard.write,
      onEvent: { if $0 == .calculatorResultCopied { didRequestHide = true } }
    )
    store.query = "2 + 3"

    store.openSelectedResult()

    #expect(clipboard.text == "5")
    #expect(didRequestHide)
    #expect(store.query == "")
    #expect(store.calculatorResult == nil)
  }

  @Test("Launcher store: Return copies quantity results with their units")
  func testReturnCopiesQuantityResultWithUnit() {
    let clipboard = RecordingClipboard()
    let store = makeStore(
      writeToClipboard: clipboard.write,
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
    calculator: CalculatorEngine = CalculatorEngine(),
    writeToClipboard: @escaping @MainActor (String) -> Void = CalculatorClipboard.write,
    launchApplication: @escaping @MainActor (InstalledApplication) async throws -> Void =
      LauncherStub().open,
    launchHistory: RecencyStore? = nil,
    shortcutCatalog: ShortcutCatalogLoading? = nil,
    runShortcut: @escaping @MainActor (AppleShortcut) async throws -> Void =
      ShortcutRunnerStub().run,
    shortcutRunHistory: RecencyStore? = nil,
    performSystemCommand: @escaping @MainActor (SystemCommand) async throws -> Void = { _ in },
    emojiHistory: EmojiHistoryStore? = nil,
    revealInFinder: @escaping @MainActor (URL) -> Void = { _ in },
    fileSearcher: FileSearching = FileSearcherStub(results: []),
    runningApplicationController: RunningApplicationControlling? = nil,
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) -> LauncherStore {
    LauncherStore(
      settingsStore: settingsStore ?? SettingsStore(userDefaults: makeTestUserDefaults()),
      catalog: catalog ?? CatalogStub(applications: applications),
      calculator: calculator,
      writeToClipboard: writeToClipboard,
      launchApplication: launchApplication,
      launchHistory: launchHistory
        ?? RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults()),
      shortcutCatalog: shortcutCatalog ?? ShortcutCatalogStub(shortcuts: shortcuts),
      runShortcut: runShortcut,
      shortcutRunHistory: shortcutRunHistory
        ?? RecencyStore.shortcutRuns(userDefaults: makeTestUserDefaults()),
      performSystemCommand: performSystemCommand,
      emojiHistory: emojiHistory ?? EmojiHistoryStore(userDefaults: makeTestUserDefaults()),
      revealInFinder: revealInFinder,
      fileSearcher: fileSearcher,
      runningApplicationController: runningApplicationController
        ?? RunningApplicationControllerStub(),
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

  func waitForApplications(_ store: LauncherStore) async {
    while store.isLoading {
      await Task.yield()
    }
  }

  func waitForShortcuts(_ store: LauncherStore) async {
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

@MainActor
final class RecordingFileSearcher: FileSearching {
  private(set) var queries = [String]()

  func search(query: String) async throws -> [FileSearchResult] {
    queries.append(query)

    return []
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

struct ShortcutRunnerStub {
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
final class RecordingShortcutRunner {
  private(set) var lastRunShortcut: AppleShortcut?

  func run(_ shortcut: AppleShortcut) async throws {
    lastRunShortcut = shortcut
  }
}

@MainActor
final class RecordingClipboard {
  private(set) var text: String?

  func write(_ text: String) {
    self.text = text
  }
}

struct LauncherStub {
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

  func cancelNext() {
    continuations.removeFirst().resume(throwing: CancellationError())
  }

  func waitForLoadCount(_ expectedCount: Int) async {
    while loadCount < expectedCount {
      await Task.yield()
    }
  }
}

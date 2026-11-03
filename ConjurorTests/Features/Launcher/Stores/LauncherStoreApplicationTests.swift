import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Filtered applications update when the query changes")
  func testQueryFiltersApplications() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = makeStore(applications: applications)
    store.loadApplications()
    await waitForApplications(store)

    #expect(store.filteredApplications == applications)

    store.query = "beta"

    #expect(store.filteredApplications == [applications[1]])
    #expect(store.selectedResultID == .application(applications[1].id))
  }

  @Test("Exclusions immediately update search and recent results without changing the catalog")
  func testExclusionsUpdateResults() async {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let stable = application("Xcode", id: "com.apple.dt.Xcode")
    let beta = application("Xcode Beta", id: "com.apple.dt.Xcode")
    let history = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    history.record(key: beta.persistenceKey)
    let store = makeStore(
      applications: [stable, beta],
      settingsStore: settings,
      launchHistory: history
    )
    store.loadApplications()
    await waitForApplications(store)
    #expect(store.filteredApplications.first == beta)

    settings.excludeApplication(beta)
    #expect(store.filteredApplications == [stable])
    #expect(store.selectedResultID == .application(stable.id))
    #expect(store.applications == [stable, beta])

    store.query = "xcode"
    settings.removeExcludedApplication(at: beta.persistenceKey)
    #expect(store.filteredApplications.contains(beta))
    store.query = ""
    #expect(store.filteredApplications.first == beta)
    store.query = "xcode"
    settings.excludeApplication(beta)
    #expect(store.filteredApplications == [stable])
    #expect(history.load()[beta.persistenceKey] != nil)

    settings.excludeApplication(stable)
    #expect(store.filteredApplications.isEmpty)
    #expect(store.selectedResultID == nil)
    settings.removeExcludedApplication(at: stable.persistenceKey)
    #expect(store.filteredApplications == [stable])
    #expect(store.selectedResultID == .application(stable.id))
  }

  @Test("Saved exclusions survive catalog reloads and mode changes")
  func testSavedExclusionsSurviveReloadsAndModes() async {
    let defaults = makeTestUserDefaults()
    let excluded = application("Example", id: "dev.example.app")
    SettingsStore(userDefaults: defaults).excludeApplication(excluded)
    let settings = SettingsStore(userDefaults: defaults)
    let store = makeStore(applications: [excluded], settingsStore: settings)
    store.loadApplications()
    await waitForApplications(store)
    #expect(store.filteredApplications.isEmpty)

    store.updateQuery("/notes")
    settings.removeExcludedApplication(at: excluded.persistenceKey)
    store.prepareForActivation(mode: .applications)
    #expect(store.filteredApplications == [excluded])
    store.updateQuery("/notes")
    settings.excludeApplication(excluded)
    store.prepareForActivation(mode: .applications)
    #expect(store.filteredApplications.isEmpty)

    store.loadApplications()
    await waitForApplications(store)
    #expect(store.filteredApplications.isEmpty)
    store.query = "bluetooth"
    #expect(store.filteredApplications.first?.isSystemSettingsItem == true)
    settings.excludeApplication(SystemSettingsCatalog.items[0])
    #expect(settings.excludedApplications.count == 1)
  }

  @Test("Selecting a second installation launches its own path")
  func testLaunchesSelectedInstallation() async {
    let stable = application("Xcode", id: "com.apple.dt.Xcode")
    let beta = application("Xcode-27.1.0-Beta", id: "com.apple.dt.Xcode")
    var launchedURL: URL?
    var didLaunch = false
    let history = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    let store = makeStore(
      applications: [stable, beta],
      launchApplication: { launchedURL = $0.url },
      launchHistory: history,
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
    )
    store.loadApplications()
    await waitForApplications(store)
    store.query = "xcode"
    #expect(store.selectedResultID == .application(stable.id))

    store.moveSelection(.down)
    #expect(store.selectedResultID == .application(beta.id))
    store.openSelectedResult()

    while !didLaunch {
      await Task.yield()
    }

    #expect(launchedURL == beta.url)
    #expect(history.load()[beta.persistenceKey] != nil)
    #expect(history.load()[stable.persistenceKey] == nil)
  }

  @Test("Command-Return reveals the selected app, but not calculations or System Settings items")
  func testRevealSelectedApplication() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    var revealedURLs = [URL]()
    var events = [LauncherEvent]()
    let store = makeStore(
      applications: applications,
      revealInFinder: { revealedURLs.append($0) },
      onEvent: { events.append($0) }
    )
    store.loadApplications()
    await waitForApplications(store)

    store.query = "2 + 2"
    store.revealSelectedResult()
    store.query = "display"
    #expect(store.filteredApplications.first?.isSystemSettingsItem == true)
    store.revealSelectedResult()
    #expect(revealedURLs.isEmpty)

    store.query = "a"
    store.select(.application(applications[1].id))
    store.revealSelectedResult()

    #expect(revealedURLs == [applications[1].url])
    #expect(events == [.itemRevealed])
    #expect(store.query.isEmpty)
  }

  @Test("Cached search follows System Settings inclusion changes")
  func testSearchIndexTracksSettingsInclusion() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let store = makeStore(settingsStore: settings)

    store.query = "bluetooth"
    #expect(store.filteredApplications.map(\.displayName) == ["Bluetooth"])
    store.query = "displays"
    #expect(store.filteredApplications.map(\.displayName) == ["Displays"])
    #expect(store.filteredApplications.first?.isSystemSettingsItem == true)
    store.query = ""
    #expect(store.filteredApplications.isEmpty)
    store.query = "bluetooth"
    #expect(store.filteredApplications.map(\.displayName) == ["Bluetooth"])

    settings.setShowsSystemSettingsItems(false)
    store.query = "bluetooth"
    #expect(store.filteredApplications.isEmpty)
    settings.setShowsSystemSettingsItems(true)
    store.query = "bluetooth"
    #expect(store.filteredApplications.map(\.displayName) == ["Bluetooth"])
  }

  @Test("Catalog reloads replace cached search data")
  func testCatalogReloadReplacesSearchIndex() async {
    let catalog = ReloadableApplicationCatalog(
      applications: [application("Alpha", id: "dev.example.app")]
    )
    let store = makeStore(catalog: catalog)
    store.loadApplications()
    await waitForApplications(store)
    store.query = "alpha"
    #expect(store.filteredApplications.map(\.displayName) == ["Alpha"])

    catalog.applications = [application("Beta", id: "dev.example.app")]
    store.loadApplications()
    await waitForApplications(store)
    #expect(store.filteredApplications.isEmpty)
    store.query = "beta"
    #expect(store.filteredApplications == catalog.applications)

    catalog.applications = []
    store.loadApplications()
    await waitForApplications(store)
    #expect(store.filteredApplications.isEmpty)
  }

  @Test("Successful launches refresh recent application order")
  func testLaunchUpdatesOrder() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    var didLaunch = false
    let store = makeStore(
      applications: applications,
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
    )
    store.loadApplications()
    await waitForApplications(store)

    store.open(applications[1])

    while !didLaunch {
      await Task.yield()
    }

    #expect(store.filteredApplications == [applications[1], applications[0]])
    #expect(store.selectedResultID == .application(applications[1].id))
  }

  @Test("Catalog failures publish errors and clear selection")
  func testCatalogFailure() async {
    let store = makeStore(
      catalog: FailingCatalogStub(),
    )

    store.loadApplications()
    await waitForApplications(store)

    #expect(store.applications.isEmpty)
    #expect(store.selectedResultID == nil)
    #expect(
      store.catalogErrorMessage == "Couldn’t load installed applications. Catalog unavailable"
    )
  }

  @Test("Successful launches record history, clear the query, and call success")
  func testSuccessfulLaunch() async {
    let application = application("Alpha", id: "dev.example.alpha")
    let userDefaults = makeTestUserDefaults()
    let launchHistory = RecencyStore.applicationLaunches(userDefaults: userDefaults)
    var didLaunch = false
    let store = makeStore(
      applications: [application],
      launchHistory: launchHistory,
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
    )
    store.loadApplications()
    await waitForApplications(store)
    store.query = "alpha"

    store.openSelectedResult()

    while !didLaunch {
      await Task.yield()
    }

    #expect(store.query == "")
    #expect(store.actionErrorMessage == nil)
    #expect(launchHistory.load()[application.persistenceKey] != nil)
  }

  @Test("Failed launches preserve the query and skip history")
  func testFailedLaunch() async {
    let application = application("Alpha", id: "dev.example.alpha")
    let launchHistory = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    var didStartLaunch = false
    var didLaunch = false
    let store = makeStore(
      applications: [application],
      launchApplication: LauncherStub(error: TestError.launchFailed).open,
      launchHistory: launchHistory,
      onEvent: { event in
        if event == .launchStarted { didStartLaunch = true }

        if event == .launchSucceeded { didLaunch = true }
      }
    )
    store.loadApplications()
    await waitForApplications(store)
    store.query = "alpha"

    store.openSelectedResult()
    #expect(didStartLaunch)
    while store.actionErrorMessage == nil {
      await Task.yield()
    }

    #expect(store.query == "alpha")
    #expect(store.actionErrorMessage == "Couldn’t open Alpha. Launch failed")
    #expect(!didLaunch)
    #expect(launchHistory.load().isEmpty)
  }

  @Test("Activation restores a failed launch")
  func testActivationAfterFailedLaunch() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = makeStore(
      applications: applications,
      launchApplication: LauncherStub(error: TestError.launchFailed).open,
    )
    store.loadApplications()
    await waitForApplications(store)
    store.query = "beta"
    store.openSelectedResult()

    while store.actionErrorMessage == nil {
      await Task.yield()
    }

    let focusRequest = store.focusRequest

    store.prepareForActivation()

    #expect(store.query == "beta")
    #expect(store.actionErrorMessage == "Couldn’t open Beta. Launch failed")
    #expect(store.selectedResultID == .application(applications[1].id))
    #expect(store.focusRequest != focusRequest)
  }
}

@MainActor
private final class ReloadableApplicationCatalog: ApplicationCatalogLoading {
  var applications: [InstalledApplication]

  init(applications: [InstalledApplication]) {
    self.applications = applications
  }

  func load() async throws -> [InstalledApplication] {
    applications
  }
}

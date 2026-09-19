import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Launcher store: filtered applications update when the query changes")
  func testFilteredApplicationsUpdateWhenQueryChanges() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = makeStore(applications: applications)
    store.loadApplications()
    await waitForLoadingToFinish(store)

    #expect(store.filteredApplications == applications)

    store.query = "beta"

    #expect(store.filteredApplications == [applications[1]])
    #expect(store.selectedApplicationID == applications[1].id)
  }

  @Test("Launcher store: selecting a second installation launches its own path")
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
    await waitForLoadingToFinish(store)
    store.query = "xcode"
    #expect(store.selectedApplicationID == stable.id)

    store.moveSelection(.down)
    #expect(store.selectedApplicationID == beta.id)
    store.openSelectedResult()
    while !didLaunch {
      await Task.yield()
    }

    #expect(launchedURL == beta.url)
    #expect(history.load()[beta.persistenceKey] != nil)
    #expect(history.load()[stable.persistenceKey] == nil)
  }

  @Test("Launcher store: System Settings sections appear in application search")
  func testSystemSettingsSectionsAppearInApplicationSearch() {
    let store = makeStore()

    store.query = "bluetooth"

    #expect(store.filteredApplications.map(\.displayName) == ["Bluetooth"])
    #expect(store.filteredApplications.first?.isSystemSettingsItem == true)
  }

  @Test("Launcher store: System Settings sections can be hidden")
  func testSystemSettingsSectionsCanBeHidden() {
    let settingsStore = SettingsStore(userDefaults: makeTestUserDefaults())
    settingsStore.setShowsSystemSettingsItems(false)
    let store = makeStore(settingsStore: settingsStore)

    store.query = "bluetooth"

    #expect(store.filteredApplications.isEmpty)
  }

  @Test("Launcher store: cached search follows System Settings inclusion changes")
  func testSearchIndexTracksSettingsInclusion() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let store = makeStore(settingsStore: settings)

    store.query = "bluetooth"
    #expect(store.filteredApplications.map(\.displayName) == ["Bluetooth"])
    store.query = "displays"
    #expect(store.filteredApplications.map(\.displayName) == ["Displays"])
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

  @Test("Launcher store: catalog reloads replace cached search data")
  func testCatalogReloadReplacesSearchIndex() async {
    let catalog = ReloadableApplicationCatalog(
      applications: [application("Alpha", id: "dev.example.app")]
    )
    let store = makeStore(catalog: catalog)
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"
    #expect(store.filteredApplications.map(\.displayName) == ["Alpha"])

    catalog.applications = [application("Beta", id: "dev.example.app")]
    store.loadApplications()
    await waitForLoadingToFinish(store)
    #expect(store.filteredApplications.isEmpty)
    store.query = "beta"
    #expect(store.filteredApplications == catalog.applications)

    catalog.applications = []
    store.loadApplications()
    await waitForLoadingToFinish(store)
    #expect(store.filteredApplications.isEmpty)
  }

  @Test("Launcher store: successful launches refresh recent application order")
  func testSuccessfulLaunchRefreshesRecentApplicationOrder() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: applications),
      launchApplication: LauncherStub().open,
      launchHistory: RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults()),
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
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
    let store = makeStore(
      catalog: FailingCatalogStub(),
      launchApplication: LauncherStub().open,
      launchHistory: RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    )

    store.loadApplications()
    await waitForLoadingToFinish(store)

    #expect(store.applications.isEmpty)
    #expect((store.selectedApplicationID) == nil)
    #expect(
      store.catalogErrorMessage == "Couldn’t load installed applications. Catalog unavailable"
    )
  }

  @Test("Launcher store: successful launches record history, clear the query, and call success")
  func testSuccessfulLaunchRecordsHistoryClearsQueryAndCallsSuccess() async {
    let application = application("Alpha", id: "dev.example.alpha")
    let userDefaults = makeTestUserDefaults()
    let launchHistory = RecencyStore.applicationLaunches(userDefaults: userDefaults)
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: [application]),
      launchApplication: LauncherStub().open,
      launchHistory: launchHistory,
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"

    store.openSelectedResult()
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
    let launchHistory = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    var didStartLaunch = false
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: [application]),
      launchApplication: LauncherStub(error: TestError.launchFailed).open,
      launchHistory: launchHistory,
      onEvent: { event in
        if event == .launchStarted { didStartLaunch = true }
        if event == .launchSucceeded { didLaunch = true }
      }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"

    store.openSelectedResult()
    #expect(didStartLaunch)
    while store.launchErrorMessage == nil {
      await Task.yield()
    }

    #expect(store.query == "alpha")
    #expect(store.launchErrorMessage == "Couldn’t open Alpha. Launch failed")
    #expect(!(didLaunch))
    #expect(launchHistory.load().isEmpty)
  }

  @Test("Launcher store: activation restores a failed launch")
  func testPrepareForActivationRestoresFailedLaunch() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    let store = makeStore(
      catalog: CatalogStub(applications: applications),
      launchApplication: LauncherStub(error: TestError.launchFailed).open,
      launchHistory: RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "beta"
    store.openSelectedResult()
    while store.launchErrorMessage == nil {
      await Task.yield()
    }
    let focusRequest = store.focusRequest

    store.prepareForActivation()

    #expect(store.query == "beta")
    #expect(store.launchErrorMessage == "Couldn’t open Beta. Launch failed")
    #expect(store.selectedApplicationID == applications[1].id)
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

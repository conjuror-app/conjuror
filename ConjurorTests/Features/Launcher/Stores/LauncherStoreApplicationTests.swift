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

  @Test("Launcher store: successful launches refresh recent application order")
  func testSuccessfulLaunchRefreshesRecentApplicationOrder() async {
    let applications = [
      application("Alpha", id: "dev.example.alpha"),
      application("Beta", id: "dev.example.beta"),
    ]
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: applications),
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults()),
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
      launcher: LauncherStub(),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults())
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
    let launchHistory = LaunchHistoryStore(userDefaults: userDefaults)
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(),
      launchHistory: launchHistory,
      onEvent: { if $0 == .launchSucceeded { didLaunch = true } }
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
    let launchHistory = LaunchHistoryStore(userDefaults: makeTestUserDefaults())
    var didStartLaunch = false
    var didLaunch = false
    let store = makeStore(
      catalog: CatalogStub(applications: [application]),
      launcher: LauncherStub(error: TestError.launchFailed),
      launchHistory: launchHistory,
      onEvent: { event in
        if event == .launchStarted { didStartLaunch = true }
        if event == .launchSucceeded { didLaunch = true }
      }
    )
    store.loadApplications()
    await waitForLoadingToFinish(store)
    store.query = "alpha"

    store.openSelectedApplication()
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
      launcher: LauncherStub(error: TestError.launchFailed),
      launchHistory: LaunchHistoryStore(userDefaults: makeTestUserDefaults())
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

    #expect(store.query == "beta")
    #expect(store.launchErrorMessage == "Couldn’t open Beta. Launch failed")
    #expect(store.selectedApplicationID == applications[1].id)
    #expect(store.focusRequest != focusRequest)
  }
}

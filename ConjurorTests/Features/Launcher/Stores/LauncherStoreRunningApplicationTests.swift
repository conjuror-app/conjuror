import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("Running apps follow exclusions while open and are released when the mode closes")
  func testRunningApplicationsLifetime() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let controller = RunningApplicationControllerStub([
      runningCandidate(10, "Safari"),
      runningCandidate(11, "Notes"),
    ])
    let store = makeStore(settingsStore: settings, runningApplicationController: controller)

    store.updateQuery("@")
    #expect(store.mode == .running)
    #expect(store.filteredRunningApplications.map(\.displayName) == ["Notes", "Safari"])
    #expect(controller.isObserving)

    settings.excludeApplication(application("Safari", id: "dev.example.safari"))
    #expect(store.filteredRunningApplications.map(\.displayName) == ["Notes"])

    store.cycleMode()
    #expect(store.mode == .systemCommands)
    #expect(store.filteredRunningApplications.isEmpty)
    #expect(!controller.isObserving)

    store.updateQuery("@no")
    store.didHide()
    #expect(store.filteredRunningApplications.isEmpty)
    #expect(!controller.isObserving)
  }

  @Test("Return switches to the selected app, or shows why it couldn't")
  func testSwitchToRunningApplication() {
    var events = [LauncherEvent]()
    let controller = RunningApplicationControllerStub([
      runningCandidate(10, "Safari"),
      runningCandidate(11, "Notes"),
    ])
    let store = makeStore(
      runningApplicationController: controller,
      onEvent: { events.append($0) }
    )

    store.updateQuery("@saf")
    store.openSelectedResult()

    #expect(controller.calls == ["activate 10"])
    #expect(events == [.runningApplicationActivated])
    #expect(events.allSatisfy { !$0.restoresPreviousFocus })
    #expect(store.query.isEmpty)

    controller.failingCalls = ["activate"]
    store.updateQuery("notes")
    store.openSelectedResult()
    #expect(store.actionErrorMessage?.hasPrefix("Couldn’t switch to Notes.") == true)
    #expect(events.count == 1)

    store.updateQuery(";")
    #expect(store.actionErrorMessage == nil)
  }

  @Test("Force quit waits for confirmation and keeps its target")
  func testForceQuitConfirmation() {
    let controller = RunningApplicationControllerStub([
      runningCandidate(10, "Notes"),
      runningCandidate(11, "Safari"),
    ])
    let store = makeStore(runningApplicationController: controller)
    store.updateQuery("@")

    store.perform(.forceQuit)
    #expect(store.pendingConfirmation == .forceQuit(store.filteredRunningApplications[0]))
    #expect(controller.calls.isEmpty)

    store.moveSelection(.down)
    #expect(store.pendingConfirmation == nil)

    store.perform(.forceQuit)
    store.cancelPendingAction()
    store.openSelectedResult()
    #expect(controller.calls == ["activate 11"])

    store.updateQuery("@")
    store.perform(.forceQuit)
    store.select(.runningApplication(11))
    store.openSelectedResult()
    #expect(controller.calls == ["activate 11", "forceQuit 10"])
    #expect(store.pendingConfirmation == nil)
  }

  @Test("Quit All confirms the listed apps and leaves Finder running")
  func testQuitAll() {
    let controller = RunningApplicationControllerStub([
      runningCandidate(10, "Finder", bundleIdentifier: "com.apple.finder"),
      runningCandidate(11, "Notes"),
      runningCandidate(12, "Numbers"),
      runningCandidate(13, "Safari"),
    ])
    let store = makeStore(runningApplicationController: controller)
    store.updateQuery("@n")

    store.perform(.quitAll)
    #expect(store.pendingConfirmation?.targets.map(\.processIdentifier) == [11, 12])
    #expect(controller.calls.isEmpty)

    store.confirmPendingAction()
    #expect(controller.calls == ["quit 11", "quit 12"])
  }

  @Test("Workspace changes update rows, keep the selection, and cancel stale confirmations")
  func testWorkspaceChanges() {
    let controller = RunningApplicationControllerStub([
      runningCandidate(10, "Notes"),
      runningCandidate(11, "Safari"),
      runningCandidate(12, "TextEdit"),
    ])
    let store = makeStore(runningApplicationController: controller)
    store.updateQuery("@")
    store.select(.runningApplication(11))

    controller.failingCalls = ["quit"]
    store.perform(.quit)
    #expect(store.actionErrorMessage?.hasPrefix("Couldn’t quit Safari.") == true)

    store.select(.runningApplication(12))
    store.perform(.forceQuit)
    controller.update([
      runningCandidate(11, "Safari", isHidden: true),
      runningCandidate(12, "TextEdit"),
    ])
    #expect(store.filteredRunningApplications.map(\.processIdentifier) == [11, 12])
    #expect(store.filteredRunningApplications[0].isHidden)
    #expect(store.selectedResultID == .runningApplication(12))
    #expect(store.pendingConfirmation != nil)

    controller.update([runningCandidate(11, "Safari")])
    #expect(store.pendingConfirmation == nil)
    #expect(store.selectedResultID == .runningApplication(11))
  }

  func runningCandidate(
    _ processIdentifier: pid_t,
    _ name: String,
    bundleIdentifier: String? = nil,
    isHidden: Bool = false
  ) -> RunningApplicationCandidate {
    RunningApplicationCandidate(
      processIdentifier: processIdentifier,
      localizedName: name,
      bundleIdentifier: bundleIdentifier,
      bundleURL: URL(fileURLWithPath: "/Applications/\(name).app"),
      isRegular: true,
      isHidden: isHidden,
      isTerminated: false
    )
  }
}

@MainActor
final class RunningApplicationControllerStub: RunningApplicationControlling {
  var failingCalls = Set<String>()
  private(set) var calls = [String]()

  var isObserving: Bool {
    observation != nil
  }

  private var runningCandidates: [RunningApplicationCandidate]
  private var onChange: (@MainActor @Sendable () -> Void)?
  private weak var observation: Observation?

  init(_ candidates: [RunningApplicationCandidate] = []) {
    runningCandidates = candidates
  }

  func update(_ candidates: [RunningApplicationCandidate]) {
    runningCandidates = candidates
    if isObserving { onChange?() }
  }

  func candidates() -> [RunningApplicationCandidate] {
    runningCandidates
  }

  func observeChanges(_ onChange: @escaping @MainActor @Sendable () -> Void) -> AnyObject {
    let observation = Observation()
    self.observation = observation
    self.onChange = onChange

    return observation
  }

  func activate(_ application: RunningApplication) throws { try record("activate", application) }
  func hide(_ application: RunningApplication) throws { try record("hide", application) }
  func hideOthers(except application: RunningApplication) throws {
    try record("hideOthers", application)
  }
  func quit(_ application: RunningApplication) throws { try record("quit", application) }
  func forceQuit(_ application: RunningApplication) throws { try record("forceQuit", application) }
  func relaunch(_ application: RunningApplication) async throws {
    try record("relaunch", application)
  }

  private func record(_ call: String, _ application: RunningApplication) throws {
    if failingCalls.contains(call) { throw TestError.launchFailed }

    calls.append("\(call) \(application.processIdentifier)")
  }
}

private final class Observation {}

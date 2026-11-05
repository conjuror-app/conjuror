import AppKit
import Testing

@testable import Conjuror

@MainActor
extension LauncherStoreTests {
  @Test("System commands rank with apps by name and keywords")
  func testSystemCommandsRankWithApplications() async {
    let restarter = application("Restarter", id: "dev.example.restarter")
    let store = makeStore(applications: [restarter])
    store.loadApplications()
    await waitForApplications(store)

    store.query = "restart"

    #expect(
      store.filteredResults.map(\.id) == [.systemCommand("restart"), .application(restarter.id)]
    )
    #expect(store.selectedResultID == .systemCommand("restart"))

    store.query = "sign out"

    #expect(store.filteredResults.map(\.id) == [.systemCommand("log-out")])
  }

  @Test("A successful command run outranks an equally matched app")
  func testSystemCommandRecency() async {
    let slack = application("Slack", id: "com.tinyspeck.slackmacgap")
    let history = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    let store = makeStore(applications: [slack], launchHistory: history)
    store.loadApplications()
    await waitForApplications(store)
    store.query = "sl"
    #expect(store.filteredResults.first?.id == .application(slack.id))

    store.run(.sleep)
    while history.load()[SystemCommand.sleep.persistenceKey] == nil {
      await Task.yield()
    }
    store.query = "sl"

    #expect(store.filteredResults.first?.id == .systemCommand("sleep"))
  }

  @Test("Turning system commands off removes them from open results")
  func testDisablingSystemCommandsUpdatesResults() async {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let sleepy = application("Sleepy", id: "dev.example.sleepy")
    let store = makeStore(applications: [sleepy], settingsStore: settings)
    store.loadApplications()
    await waitForApplications(store)
    store.query = "sleep"
    #expect(store.selectedResultID == .systemCommand("sleep"))

    settings.setShowsSystemCommands(false)

    #expect(store.filteredResults.map(\.id) == [.application(sleepy.id)])
    #expect(store.selectedResultID == .application(sleepy.id))
  }

  @Test("Destructive commands run only after a second Return")
  func testConfirmationRunsOnSecondReturn() async {
    let performer = RecordingSystemCommandPerformer()
    var events = [LauncherEvent]()
    let store = makeStore(performSystemCommand: performer.perform, onEvent: { events.append($0) })
    store.query = "empty trash"

    store.openSelectedResult()

    #expect(store.armedCommand == .emptyTrash)
    #expect(events.isEmpty)

    store.openSelectedResult()
    while performer.commands.isEmpty {
      await Task.yield()
    }

    #expect(performer.commands == [.emptyTrash])
    #expect(events == [.systemCommandStarted])
    #expect(store.armedCommand == nil)
  }

  @Test("Editing, moving, cancelling, or reopening disarms a command")
  func testConfirmationIsCancelled() {
    let store = makeStore()

    store.query = "eject"
    store.openSelectedResult()
    store.query = "eject all"
    #expect(store.armedCommand == nil)

    store.openSelectedResult()
    store.moveSelection(.down)
    #expect(store.armedCommand == nil)

    store.openSelectedResult()
    store.cancelConfirmation()
    #expect(store.armedCommand == nil)

    store.openSelectedResult()
    store.prepareForActivation()
    #expect(store.armedCommand == nil)
  }

  @Test("Commands with a system dialog run on the first Return and restore focus")
  func testRestartRunsImmediately() async {
    let performer = RecordingSystemCommandPerformer()
    var events = [LauncherEvent]()
    let store = makeStore(performSystemCommand: performer.perform, onEvent: { events.append($0) })
    store.query = "restart"

    store.openSelectedResult()
    while performer.commands.isEmpty {
      await Task.yield()
    }

    #expect(performer.commands == [.restart])
    #expect(events == [.systemCommandStarted])
    #expect(LauncherEvent.systemCommandStarted.restoresPreviousFocus)
  }

  @Test("Exclamation mark lists every command, most recent first")
  func testSystemCommandsMode() async {
    let history = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    let store = makeStore(launchHistory: history)

    store.updateQuery("!")

    #expect(store.mode == .systemCommands)
    #expect(store.filteredSystemCommands.count == SystemCommand.allCases.count)
    #expect(store.selectedRevealableURL == nil)

    store.run(.toggleDarkMode)
    while history.load()[SystemCommand.toggleDarkMode.persistenceKey] == nil {
      await Task.yield()
    }

    #expect(store.mode == .systemCommands)
    #expect(store.filteredSystemCommands.first == .toggleDarkMode)
  }

  @Test("Disabled system commands are skipped by the prefix and Tab")
  func testDisabledSystemCommandsMode() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    settings.setShowsSystemCommands(false)
    let store = makeStore(settingsStore: settings)

    store.updateQuery("!sleep")
    #expect(store.mode == .applications)
    #expect(store.query == "!sleep")

    store.prepareForActivation(mode: .files)
    store.cycleMode()
    #expect(store.mode == .applications)
  }

  @Test("Turning system commands off leaves the commands mode")
  func testDisablingSystemCommandsLeavesMode() {
    let settings = SettingsStore(userDefaults: makeTestUserDefaults())
    let store = makeStore(settingsStore: settings)
    store.updateQuery("!")

    settings.setShowsSystemCommands(false)

    #expect(store.mode == .applications)
  }

  @Test("Failed commands show an error in their mode without recording history")
  func testFailedSystemCommand() async {
    let history = RecencyStore.applicationLaunches(userDefaults: makeTestUserDefaults())
    let store = makeStore(
      launchHistory: history,
      performSystemCommand: { _ in throw SystemCommandError.permissionDenied(appName: "Finder") }
    )
    store.updateQuery("!empty")
    store.openSelectedResult()
    store.openSelectedResult()

    while store.actionErrorMessage == nil {
      await Task.yield()
    }

    #expect(
      store.actionErrorMessage
        == "Couldn’t run Empty Trash. Allow Conjuror to control Finder in System Settings › "
        + "Privacy & Security › Automation."
    )
    #expect(history.load().isEmpty)

    store.prepareForActivation()
    #expect(store.mode == .systemCommands)
  }
}

@MainActor
final class RecordingSystemCommandPerformer {
  private(set) var commands = [SystemCommand]()

  func perform(_ command: SystemCommand) async throws {
    commands.append(command)
  }
}

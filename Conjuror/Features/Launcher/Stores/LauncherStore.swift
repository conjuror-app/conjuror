import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
  private static func emoji(for values: [String]) -> [Emoji] {
    values.compactMap { Emoji.byValue[$0] }
  }

  @Published var query = "" {
    didSet {
      armedCommand = nil
      pendingConfirmation = nil
      refreshCurrentResults()
      selectFirstResult()

      if actionError?.mode == mode { actionError = nil }
    }
  }

  @Published private(set) var mode = LauncherMode.applications
  @Published private(set) var applications = [InstalledApplication]()
  @Published private(set) var filteredResults = [ApplicationSearchResult]()
  @Published private(set) var catalogErrorMessage: String?
  @Published private(set) var isLoading = false
  @Published private(set) var calculatorResult: CalculatorResult?
  @Published private(set) var shortcuts = [AppleShortcut]()
  @Published private(set) var filteredShortcuts = [AppleShortcut]()
  @Published private(set) var shortcutCatalogErrorMessage: String?
  @Published private(set) var isLoadingShortcuts = false
  @Published private(set) var filteredEmoji = [Emoji]()
  @Published private(set) var recentEmoji = [Emoji]()
  @Published private(set) var fileResults = [FileSearchResult]()
  @Published private(set) var isSearchingFiles = false
  @Published private(set) var fileSearchErrorMessage: String?
  @Published private(set) var filteredSystemCommands = [SystemCommand]()
  /// The command waiting for a second Return before it runs.
  @Published private(set) var armedCommand: SystemCommand?
  @Published private(set) var filteredRunningApplications = [RunningApplication]()
  @Published private(set) var pendingConfirmation: RunningApplicationConfirmation?
  @Published private(set) var selectedResultID: LauncherResultID?
  @Published private(set) var selectionScrollRequest = 0
  @Published private(set) var focusRequest = 0

  /// The failed action's message, shown only in the mode that started the action.
  var actionErrorMessage: String? {
    actionError?.mode == mode ? actionError?.message : nil
  }

  var isCalculatorSelected: Bool {
    selectedResultID == .calculator
  }

  /// The apps and System Settings sections in the ranked application results.
  var filteredApplications: [InstalledApplication] {
    filteredResults.compactMap(\.application)
  }

  var handlesRunningApplicationCommands: Bool {
    mode == .running
  }

  var displayedEmoji: [Emoji] {
    let emoji = preferredEmoji

    guard query.isEmpty else { return emoji }

    let recentIDs = Set(recentEmoji.map(\.id))

    return recentEmoji + emoji.filter { !recentIDs.contains($0.id) }
  }

  /// The selected app or file, which Finder can reveal. Calculations, emoji, shortcuts, and
  /// System Settings items have no file to reveal.
  var selectedRevealableURL: URL? {
    switch mode {
    case .applications:
      guard !isCalculatorSelected,
        let application = selected(in: filteredResults, as: { $0 })?.application,
        !application.isSystemSettingsItem
      else {
        return nil
      }

      return application.url
    case .files:
      return selected(in: fileResults, as: { .file($0) })?.url
    case .running:
      return selectedRunningApplication?.bundleURL
    case .emoji, .shortcuts, .systemCommands:
      return nil
    }
  }

  private let settingsStore: SettingsStore
  private let catalog: ApplicationCatalogLoading
  private let calculator: CalculatorEngine
  private let writeToClipboard: @MainActor (String) -> Void
  private let launchApplication: @MainActor (InstalledApplication) async throws -> Void
  private let shortcutCatalog: ShortcutCatalogLoading
  private let runShortcut: @MainActor (AppleShortcut) async throws -> Void
  private let performSystemCommand: @MainActor (SystemCommand) async throws -> Void
  private let revealInFinder: @MainActor (URL) -> Void
  private let runningApplicationController: RunningApplicationControlling
  private let emojiHistory: EmojiHistoryStore
  private let applicationController: RankedCatalog<ApplicationSearchResult>
  private let shortcutController: RankedCatalog<AppleShortcut>
  private let systemCommandController: RankedCatalog<SystemCommand>
  private let fileController: LauncherFileController
  private let onEvent: (LauncherEvent) -> Void

  private var currencyRates: CurrencyRates?
  private let applicationLoader = CatalogLoader<InstalledApplication>()
  private let shortcutsLoader = CatalogLoader<AppleShortcut>()
  private var excludedApplicationPaths = Set<String>()
  private var exclusionSubscription: AnyCancellable?
  private var showsSystemCommands = true
  private var systemCommandsSubscription: AnyCancellable?
  /// The optional items in the application search index, rebuilt only when they change.
  private var catalogComposition: CatalogComposition?
  private var emojiIndex: EmojiRanker.Index?
  private var hasLoadedEmoji = false
  private var hasLoadedShortcuts = false
  private var runningShortcutIDs = Set<AppleShortcut.ID>()
  private var lastPointerLocation: NSPoint?
  private var runningApplicationIndex: SearchIndex<RunningApplication>?
  private var runningApplicationObservation: AnyObject?
  @Published private var actionError: ActionError?

  private var preferredEmoji: [Emoji] {
    guard !EmojiRanker.requestsSkinTone(query) else { return filteredEmoji }

    return Emoji.withPreferredSkinTone(filteredEmoji, settingsStore.preferredEmojiSkinTone)
  }

  private var selectedRunningApplication: RunningApplication? {
    selected(in: filteredRunningApplications, as: { .runningApplication($0) })
  }

  private var resultIDs: [LauncherResultID] {
    switch mode {
    case .applications:
      (calculatorResult == nil ? [] : [.calculator]) + filteredResults.map(\.id)
    case .emoji:
      displayedEmoji.map { .emoji($0.id) }
    case .files:
      fileResults.map { .file($0.id) }
    case .running:
      filteredRunningApplications.map { .runningApplication($0.id) }
    case .shortcuts:
      filteredShortcuts.map { .shortcut($0.id) }
    case .systemCommands:
      filteredSystemCommands.map { .systemCommand($0.id) }
    }
  }

  init(
    settingsStore: SettingsStore = SettingsStore(),
    catalog: ApplicationCatalogLoading = ApplicationCatalog(),
    calculator: CalculatorEngine = CalculatorEngine(),
    writeToClipboard: @escaping @MainActor (String) -> Void = CalculatorClipboard.write,
    launchApplication: @escaping @MainActor (InstalledApplication) async throws -> Void =
      ApplicationLauncher().open,
    launchHistory: RecencyStore = .applicationLaunches(),
    shortcutCatalog: ShortcutCatalogLoading = ShortcutCatalog(),
    runShortcut: @escaping @MainActor (AppleShortcut) async throws -> Void = ShortcutRunner().run,
    shortcutRunHistory: RecencyStore = .shortcutRuns(),
    performSystemCommand: @escaping @MainActor (SystemCommand) async throws -> Void =
      SystemCommandRunner().run,
    emojiHistory: EmojiHistoryStore = EmojiHistoryStore(),
    revealInFinder: @escaping @MainActor (URL) -> Void = {
      NSWorkspace.shared.activateFileViewerSelecting([$0])
    },
    fileSearcher: FileSearching = SpotlightFileSearchService(),
    runningApplicationController: RunningApplicationControlling =
      WorkspaceRunningApplicationController(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) {
    self.settingsStore = settingsStore
    self.catalog = catalog
    self.calculator = calculator
    self.writeToClipboard = writeToClipboard
    self.launchApplication = launchApplication
    self.shortcutCatalog = shortcutCatalog
    self.runShortcut = runShortcut
    self.performSystemCommand = performSystemCommand
    self.emojiHistory = emojiHistory
    self.revealInFinder = revealInFinder
    applicationController = RankedCatalog(history: launchHistory)
    shortcutController = RankedCatalog(history: shortcutRunHistory)
    // Commands share app launch history so their recency ranks consistently in both modes.
    systemCommandController = RankedCatalog(history: launchHistory)
    systemCommandController.replace(SystemCommand.allCases)
    fileController = LauncherFileController(searcher: fileSearcher)
    self.runningApplicationController = runningApplicationController
    self.onEvent = onEvent

    exclusionSubscription = settingsStore.$excludedApplications
      .sink { [weak self] exclusions in
        guard let self else { return }

        excludedApplicationPaths = Set(exclusions.keys)
        catalogComposition = nil
        refreshApplications()
        reloadRunningApplications()
        if mode == .applications, !resultIDs.contains(where: { $0 == self.selectedResultID }) {
          selectFirstResult()
        }
      }

    systemCommandsSubscription = settingsStore.$showsSystemCommands
      .sink { [weak self] showsCommands in
        self?.setShowsSystemCommands(showsCommands)
      }
  }

  func setCurrencyRates(_ rates: CurrencyRates?) {
    guard rates != currencyRates else {
      return
    }

    currencyRates = rates
    refreshCurrentResults()
    selectFirstResult()
  }

  func updateQuery(_ value: String) {
    guard let prefix = value.first,
      let requestedMode = LauncherMode.requested(byPrefix: prefix),
      isEnabled(requestedMode)
    else {
      query = value

      return
    }

    transition(to: requestedMode, query: String(value.dropFirst()))
  }

  func cycleMode() {
    var nextMode = mode.next

    while !isEnabled(nextMode) { nextMode = nextMode.next }

    transition(to: nextMode)
  }

  func loadApplications() {
    catalogErrorMessage = nil
    let catalog = catalog
    applicationLoader.load(
      operation: catalog.load,
      onLoadingChange: { [weak self] in self?.isLoading = $0 },
      completion: { [weak self] result in
        guard let self else { return }

        switch result {
        case .success(let applications):
          replaceApplications(with: applications)
        case .failure(let error):
          replaceApplications(with: [])
          catalogErrorMessage =
            "Couldn’t load installed applications. \(error.localizedDescription)"
        }

        if mode == .applications { selectFirstResult() }
      }
    )
  }

  func loadShortcuts() {
    guard !hasLoadedShortcuts else { return }

    hasLoadedShortcuts = true
    shortcutCatalogErrorMessage = nil
    let shortcutCatalog = shortcutCatalog
    shortcutsLoader.load(
      operation: shortcutCatalog.load,
      onLoadingChange: { [weak self] in self?.isLoadingShortcuts = $0 },
      completion: { [weak self] result in
        guard let self else { return }

        switch result {
        case .success(let shortcuts):
          replaceShortcuts(with: shortcuts)
        case .failure(let error):
          hasLoadedShortcuts = false
          replaceShortcuts(with: [])
          shortcutCatalogErrorMessage = "Couldn’t load shortcuts. \(error.localizedDescription)"
        }

        if mode == .shortcuts { selectFirstResult() }
      }
    )
  }

  func select(_ id: LauncherResultID) {
    if id != selectedResultID { armedCommand = nil }

    selectedResultID = id
  }

  func selectOnHover(_ id: LauncherResultID) {
    guard pointerDidMove() else { return }

    select(id)
  }

  func moveSelection(_ direction: MoveCommandDirection) {
    pendingConfirmation = nil
    lastPointerLocation = NSEvent.mouseLocation
    armedCommand = nil
    selectedResultID = movedSelection(
      direction,
      results: resultIDs,
      selectedID: selectedResultID,
      step: mode.allowsHorizontalNavigation ? LauncherLayout.emojiColumnCount : 1
    )
  }

  func openSelectedResult() {
    switch mode {
    case .applications:
      if isCalculatorSelected {
        copyCalculatorResult()
      } else if let result = selected(in: filteredResults, as: { $0 }) {
        switch result {
        case .application(let application): open(application)
        case .systemCommand(let command): run(command)
        }
      }
    case .emoji:
      if let emoji = selected(in: displayedEmoji, as: { .emoji($0) }) { copy(emoji) }
    case .files:
      if let file = selected(in: fileResults, as: { .file($0) }) { open(file) }
    case .running:
      if pendingConfirmation != nil {
        confirmPendingAction()
      } else if let application = selectedRunningApplication {
        switchTo(application)
      }
    case .shortcuts:
      if let shortcut = selected(in: filteredShortcuts, as: { .shortcut($0) }) { run(shortcut) }
    case .systemCommands:
      if let command = selected(in: filteredSystemCommands, as: { .systemCommand($0) }) {
        run(command)
      }
    }
  }

  func revealSelectedResult() {
    guard let url = selectedRevealableURL else { return }

    revealInFinder(url)
    query = ""
    onEvent(.itemRevealed)
  }

  func open(_ application: InstalledApplication) {
    selectedResultID = .application(application.id)
    actionError = nil
    onEvent(.launchStarted)

    let launchApplication = launchApplication
    perform(
      operation: { try await launchApplication(application) },
      onSuccess: { [weak self] in
        guard let self else { return }

        applicationController.record(key: application.persistenceKey)
        query = ""
        onEvent(.launchSucceeded)
      },
      onFailure: { [weak self] error in
        self?.actionError = ActionError(
          mode: .applications,
          message: "Couldn’t open \(application.displayName). \(error.localizedDescription)"
        )
      }
    )
  }

  func copyCalculatorResult() {
    guard let calculatorResult else {
      return
    }

    writeToClipboard(calculatorResult.copyText)
    query = ""
    onEvent(.calculatorResultCopied)
  }

  func copy(_ emoji: Emoji) {
    writeToClipboard(emoji.value)
    emojiHistory.record(emoji)
    recentEmoji = Self.emoji(for: emojiHistory.load())
    query = ""
    mode = .applications
    onEvent(.emojiCopied)
  }

  func open(_ file: FileSearchResult) {
    selectedResultID = .file(file.id)
    actionError = nil

    guard NSWorkspace.shared.open(file.url) else {
      actionError = ActionError(
        mode: .files,
        message: "Couldn’t open \(file.displayName). The item could not be opened."
      )

      return
    }

    query = ""
    onEvent(.fileOpened)
  }

  func run(_ shortcut: AppleShortcut) {
    guard !shortcut.acceptsInput,
      runningShortcutIDs.insert(shortcut.id).inserted
    else {
      return
    }

    selectedResultID = .shortcut(shortcut.id)
    actionError = nil
    onEvent(.shortcutRunStarted)

    let runShortcut = runShortcut
    perform(
      operation: { try await runShortcut(shortcut) },
      onSuccess: { [weak self] in
        guard let self else { return }

        shortcutController.record(key: shortcut.persistenceKey)
        runningShortcutIDs.remove(shortcut.id)
        query = ""
      },
      onFailure: { [weak self] error in
        self?.runningShortcutIDs.remove(shortcut.id)
        self?.actionError = ActionError(
          mode: .shortcuts,
          message: "Couldn’t run \(shortcut.name). \(error.localizedDescription)"
        )
      }
    )
  }

  /// Runs a command, or arms it first when it needs a second Return to confirm.
  func run(_ command: SystemCommand) {
    selectedResultID = .systemCommand(command.id)

    guard !command.requiresConfirmation || armedCommand == command else {
      armedCommand = command

      return
    }

    armedCommand = nil
    actionError = nil
    onEvent(.systemCommandStarted)

    let mode = mode
    let performSystemCommand = performSystemCommand
    perform(
      operation: { try await performSystemCommand(command) },
      onSuccess: { [weak self] in
        guard let self else { return }

        applicationController.record(key: command.persistenceKey)
        systemCommandController.reloadHistory()
        query = ""
      },
      onFailure: { [weak self] error in
        self?.actionError = ActionError(
          mode: mode,
          message: "Couldn’t run \(command.title). \(error.localizedDescription)"
        )
      }
    )
  }

  func cancelConfirmation() {
    armedCommand = nil
  }

  func switchTo(_ application: RunningApplication) {
    selectedResultID = .runningApplication(application.id)
    pendingConfirmation = nil

    guard
      attempt("switch to", application, { try runningApplicationController.activate($0) })
    else {
      return
    }

    query = ""
    onEvent(.runningApplicationActivated)
  }

  func perform(_ command: RunningApplicationCommand) {
    guard mode == .running else { return }

    actionError = nil
    pendingConfirmation = nil

    if command == .quitAll {
      let applications = filteredRunningApplications.filter { !$0.isFinder }
      if !applications.isEmpty { pendingConfirmation = .quitAll(applications) }

      return
    }

    guard let application = selectedRunningApplication else { return }

    let controller = runningApplicationController
    switch command {
    case .forceQuit:
      pendingConfirmation = .forceQuit(application)
    case .hide:
      attempt("hide", application, controller.hide)
    case .hideOthers:
      guard attempt("hide apps other than", application, controller.hideOthers) else { return }

      query = ""
      onEvent(.runningApplicationActivated)
    case .quit:
      attempt("quit", application, controller.quit)
    case .quitAll:
      break
    case .relaunch:
      perform(
        operation: { try await controller.relaunch(application) },
        onSuccess: {},
        onFailure: { [weak self] error in
          self?.actionError = ActionError(
            mode: .running,
            message: "Couldn’t relaunch \(application.displayName). \(error.localizedDescription)"
          )
        }
      )
      query = ""
      onEvent(.runningApplicationActivated)
    }
  }

  func confirmPendingAction() {
    guard let confirmation = pendingConfirmation else { return }

    pendingConfirmation = nil
    let controller = runningApplicationController
    switch confirmation {
    case .forceQuit(let application):
      attempt("force quit", application, controller.forceQuit)
    case .quitAll(let applications):
      for application in applications {
        attempt("quit", application, controller.quit)
      }
    }
  }

  func cancelPendingAction() {
    pendingConfirmation = nil
  }

  /// Releases results that only matter while the launcher is visible.
  func didHide() {
    pendingConfirmation = nil
    stopRunningApplications()
  }

  func clearActionError() {
    actionError = nil
  }

  func prepareForActivation(mode requestedMode: LauncherMode? = nil) {
    armedCommand = nil

    if let requestedMode {
      actionError = nil
      transition(to: requestedMode)
    } else if let actionError {
      // Reopen where the action failed so its error and query are still visible.
      transition(to: actionError.mode, query: nil)
    } else {
      transition(to: .applications)
    }

    focusRequest &+= 1
  }

  private func perform(
    operation: @escaping () async throws -> Void,
    onSuccess: @escaping () -> Void,
    onFailure: @escaping (Error) -> Void
  ) {
    Task {
      do {
        try await operation()

        guard !Task.isCancelled else { return }

        onSuccess()
      } catch is CancellationError {
        return
      } catch {
        onFailure(error)
      }
    }
  }

  private func isEnabled(_ mode: LauncherMode) -> Bool {
    switch mode {
    case .files: settingsStore.isFilesModuleEnabled
    case .systemCommands: showsSystemCommands
    case .applications, .emoji, .running, .shortcuts: true
    }
  }

  private func setShowsSystemCommands(_ showsCommands: Bool) {
    guard showsCommands != showsSystemCommands else { return }

    showsSystemCommands = showsCommands
    catalogComposition = nil

    if mode == .systemCommands, !showsCommands {
      transition(to: .applications)
    } else if mode == .applications {
      refreshApplications()
      if !resultIDs.contains(where: { $0 == selectedResultID }) { selectFirstResult() }
    }
  }

  private func transition(to mode: LauncherMode, query: String? = "") {
    let mode = isEnabled(mode) ? mode : .applications
    self.mode = mode
    pendingConfirmation = nil

    if mode == .running {
      startRunningApplications()
    } else {
      stopRunningApplications()
    }

    if let query {
      self.query = query
    } else {
      refreshCurrentResults()
      selectFirstResult()
    }

    if mode == .shortcuts { loadShortcuts() }
  }

  private func pointerDidMove() -> Bool {
    let pointerLocation = NSEvent.mouseLocation

    guard pointerLocation != lastPointerLocation else {
      return false
    }

    lastPointerLocation = pointerLocation

    return true
  }

  private func movedSelection<ID: Equatable>(
    _ direction: MoveCommandDirection,
    results: [ID],
    selectedID: ID?,
    step: Int = 1
  ) -> ID? {
    guard !results.isEmpty else {
      return nil
    }

    let currentIndex = selectedID.flatMap(results.firstIndex(of:)) ?? 0
    let nextIndex: Int

    switch direction {
    case .down:
      nextIndex = min(currentIndex + step, results.count - 1)
    case .up:
      nextIndex = max(currentIndex - step, 0)
    case .left:
      nextIndex = max(currentIndex - 1, 0)
    case .right:
      nextIndex = min(currentIndex + 1, results.count - 1)
    default:
      return selectedID
    }

    selectionScrollRequest &+= 1

    return results[nextIndex]
  }

  private func selectFirstResult() {
    selectedResultID = resultIDs.first
    selectionScrollRequest &+= 1
  }

  private func selected<Item: Identifiable>(
    in items: [Item],
    as resultID: (Item.ID) -> LauncherResultID
  ) -> Item? {
    items.first { resultID($0.id) == selectedResultID } ?? items.first
  }

  private func replaceApplications(with applications: [InstalledApplication]) {
    self.applications = applications
    catalogComposition = nil
    refreshApplications()
  }

  private func replaceShortcuts(with shortcuts: [AppleShortcut]) {
    self.shortcuts = shortcuts
    shortcutController.replace(shortcuts)
    refreshShortcuts()
  }

  private func refreshCurrentResults() {
    calculatorResult = nil

    if mode != .files {
      fileController.cancel()
      isSearchingFiles = false
    }

    switch mode {
    case .applications: refreshApplications()
    case .emoji:
      loadEmojiIfNeeded()
      filteredEmoji = emojiIndex?.ranked(query: query) ?? []
    case .files: searchFiles()
    case .running: refreshRunningApplications()
    case .shortcuts: refreshShortcuts()
    case .systemCommands: refreshSystemCommands()
    }
  }

  private func loadEmojiIfNeeded() {
    guard !hasLoadedEmoji else { return }

    hasLoadedEmoji = true
    emojiIndex = EmojiRanker.Index(emoji: Emoji.catalog)
    recentEmoji = Self.emoji(for: emojiHistory.load())
  }

  private func searchFiles() {
    fileSearchErrorMessage = nil
    fileController.search(query: query) { [weak self] update in
      guard let self, mode == .files else { return }

      switch update {
      case .cleared:
        fileResults = []
        selectedResultID = nil
        isSearchingFiles = false
      case .searching:
        isSearchingFiles = true
      case .results(let results):
        fileResults = results
        selectedResultID = results.first.map { .file($0.id) }
        isSearchingFiles = false
      case .failed(let error):
        fileResults = []
        selectedResultID = nil
        fileSearchErrorMessage = "Couldn’t search files. \(error.localizedDescription)"
        isSearchingFiles = false
      }
    }
  }

  private func refreshApplications() {
    guard mode == .applications else { return }

    let hasQuery = !query.trimmingCharacters(in: .whitespaces).isEmpty
    let composition = CatalogComposition(
      includesSystemSettings: settingsStore.showsSystemSettingsItems && hasQuery,
      includesSystemCommands: showsSystemCommands && hasQuery
    )
    if catalogComposition != composition {
      var visibleApplications = applications.filter {
        !excludedApplicationPaths.contains($0.persistenceKey)
      }
      if composition.includesSystemSettings { visibleApplications += SystemSettingsCatalog.items }

      var results = visibleApplications.map(ApplicationSearchResult.application)
      if composition.includesSystemCommands {
        results += SystemCommand.allCases.map(ApplicationSearchResult.systemCommand)
      }

      applicationController.replace(results)
      catalogComposition = composition
    }

    calculatorResult = calculator.evaluate(query, currencyRates: currencyRates)
    filteredResults = applicationController.ranked(query: query)
  }

  /// Builds the running app list when its mode opens and follows workspace changes until it closes.
  private func startRunningApplications() {
    guard runningApplicationObservation == nil else { return }

    runningApplicationObservation = runningApplicationController.observeChanges { [weak self] in
      self?.reloadRunningApplications()
    }
    reloadRunningApplications()
  }

  private func stopRunningApplications() {
    runningApplicationObservation = nil
    runningApplicationIndex = nil
    filteredRunningApplications = []
  }

  private func reloadRunningApplications() {
    guard mode == .running, runningApplicationObservation != nil else { return }

    let applications = RunningApplicationCatalog.applications(
      from: runningApplicationController.candidates(),
      ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
      installed: self.applications,
      excludedPaths: excludedApplicationPaths
    )
    runningApplicationIndex = SearchIndex(applications)

    let runningIDs = Set(applications.map(\.id))
    if let pendingConfirmation,
      !pendingConfirmation.targets.allSatisfy({ runningIDs.contains($0.id) })
    {
      self.pendingConfirmation = nil
    }

    let selectedID = selectedResultID
    refreshRunningApplications()
    if let selectedID, resultIDs.contains(selectedID) {
      selectedResultID = selectedID
    } else {
      selectFirstResult()
    }
  }

  private func refreshRunningApplications() {
    guard mode == .running else { return }

    filteredRunningApplications = runningApplicationIndex?.ranked(query: query, recency: [:]) ?? []
  }

  /// Runs an action on a running app, showing its error in Running apps mode.
  @discardableResult
  private func attempt(
    _ verb: String,
    _ application: RunningApplication,
    _ action: @MainActor (RunningApplication) throws -> Void
  ) -> Bool {
    do {
      try action(application)

      return true
    } catch {
      actionError = ActionError(
        mode: .running,
        message: "Couldn’t \(verb) \(application.displayName). \(error.localizedDescription)"
      )

      return false
    }
  }

  private func refreshShortcuts() {
    guard mode == .shortcuts else { return }

    filteredShortcuts = shortcutController.ranked(query: query)
  }

  private func refreshSystemCommands() {
    guard mode == .systemCommands else { return }

    filteredSystemCommands = systemCommandController.ranked(query: query)
  }
}

private struct CatalogComposition: Equatable {
  let includesSystemSettings: Bool
  let includesSystemCommands: Bool
}

private struct ActionError {
  let mode: LauncherMode
  let message: String
}

enum LauncherEvent: Equatable {
  case calculatorResultCopied
  case emojiCopied
  case fileOpened
  case itemRevealed
  case launchStarted
  case launchSucceeded
  case runningApplicationActivated
  case shortcutRunStarted
  case systemCommandStarted

  /// Copies, shortcut runs, and system commands leave no other app to take focus, so the launcher
  /// returns it to the previous app.
  var restoresPreviousFocus: Bool {
    switch self {
    case .calculatorResultCopied, .emojiCopied, .shortcutRunStarted, .systemCommandStarted: true
    case .fileOpened, .itemRevealed, .launchStarted, .launchSucceeded,
      .runningApplicationActivated:
      false
    }
  }
}

enum LauncherResultID: Hashable {
  case application(InstalledApplication.ID)
  case calculator
  case emoji(Emoji.ID)
  case file(FileSearchResult.ID)
  case runningApplication(RunningApplication.ID)
  case shortcut(AppleShortcut.ID)
  case systemCommand(SystemCommand.ID)
}

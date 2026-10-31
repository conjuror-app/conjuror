import AppKit
import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
  private static func emoji(for values: [String]) -> [Emoji] {
    values.compactMap { Emoji.byValue[$0] }
  }

  @Published var query = "" {
    didSet {
      refreshCurrentResults()
      selectFirstResult()

      if actionError?.mode == mode { actionError = nil }
    }
  }

  @Published private(set) var mode = LauncherMode.applications
  @Published private(set) var applications = [InstalledApplication]()
  @Published private(set) var filteredApplications = [InstalledApplication]()
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

  var displayedEmoji: [Emoji] {
    let emoji = preferredEmoji

    guard query.isEmpty else { return emoji }

    let recentIDs = Set(recentEmoji.map(\.id))

    return recentEmoji + emoji.filter { !recentIDs.contains($0.id) }
  }

  private let settingsStore: SettingsStore
  private let catalog: ApplicationCatalogLoading
  private let calculator: CalculatorEngine
  private let writeToClipboard: @MainActor (String) -> Void
  private let launchApplication: @MainActor (InstalledApplication) async throws -> Void
  private let shortcutCatalog: ShortcutCatalogLoading
  private let runShortcut: @MainActor (AppleShortcut) async throws -> Void
  private let emojiHistory: EmojiHistoryStore
  private let applicationController: RankedCatalog<InstalledApplication>
  private let shortcutController: RankedCatalog<AppleShortcut>
  private let fileController: LauncherFileController
  private let onEvent: (LauncherEvent) -> Void

  private var currencyRates: CurrencyRates?
  private let applicationLoader = CatalogLoader<InstalledApplication>()
  private let shortcutsLoader = CatalogLoader<AppleShortcut>()
  private var includesSystemSettings: Bool?
  private var emojiIndex: EmojiRanker.Index?
  private var hasLoadedEmoji = false
  private var hasLoadedShortcuts = false
  private var runningShortcutIDs = Set<AppleShortcut.ID>()
  private var lastPointerLocation: NSPoint?
  @Published private var actionError: ActionError?

  private var preferredEmoji: [Emoji] {
    guard !EmojiRanker.requestsSkinTone(query) else { return filteredEmoji }

    return Emoji.withPreferredSkinTone(filteredEmoji, settingsStore.preferredEmojiSkinTone)
  }

  private var resultIDs: [LauncherResultID] {
    switch mode {
    case .applications:
      (calculatorResult == nil ? [] : [.calculator])
        + filteredApplications.map { .application($0.id) }
    case .emoji:
      displayedEmoji.map { .emoji($0.id) }
    case .files:
      fileResults.map { .file($0.id) }
    case .shortcuts:
      filteredShortcuts.map { .shortcut($0.id) }
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
    emojiHistory: EmojiHistoryStore = EmojiHistoryStore(),
    fileSearcher: FileSearching = SpotlightFileSearchService(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) {
    self.settingsStore = settingsStore
    self.catalog = catalog
    self.calculator = calculator
    self.writeToClipboard = writeToClipboard
    self.launchApplication = launchApplication
    self.shortcutCatalog = shortcutCatalog
    self.runShortcut = runShortcut
    self.emojiHistory = emojiHistory
    applicationController = RankedCatalog(history: launchHistory)
    shortcutController = RankedCatalog(history: shortcutRunHistory)
    fileController = LauncherFileController(searcher: fileSearcher)
    self.onEvent = onEvent
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
      requestedMode != .files || settingsStore.isFilesModuleEnabled
    else {
      query = value

      return
    }

    transition(to: requestedMode, query: String(value.dropFirst()))
  }

  func cycleMode() {
    transition(to: mode.next)
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
    selectedResultID = id
  }

  func selectOnHover(_ id: LauncherResultID) {
    guard pointerDidMove() else { return }

    select(id)
  }

  func moveSelection(_ direction: MoveCommandDirection) {
    lastPointerLocation = NSEvent.mouseLocation
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
      } else if let application = selected(in: filteredApplications, as: { .application($0) }) {
        open(application)
      }
    case .emoji:
      if let emoji = selected(in: displayedEmoji, as: { .emoji($0) }) { copy(emoji) }
    case .files:
      if let file = selected(in: fileResults, as: { .file($0) }) { open(file) }
    case .shortcuts:
      if let shortcut = selected(in: filteredShortcuts, as: { .shortcut($0) }) { run(shortcut) }
    }
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

  func clearActionError() {
    actionError = nil
  }

  func prepareForActivation(mode requestedMode: LauncherMode? = nil) {
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

  private func transition(to mode: LauncherMode, query: String? = "") {
    let mode = mode == .files && !settingsStore.isFilesModuleEnabled ? .applications : mode
    self.mode = mode

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
    includesSystemSettings = nil
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
    case .shortcuts: refreshShortcuts()
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

    let includesSystemSettings =
      settingsStore.showsSystemSettingsItems && !query.trimmingCharacters(in: .whitespaces).isEmpty
    if self.includesSystemSettings != includesSystemSettings {
      applicationController.replace(
        includesSystemSettings ? applications + SystemSettingsCatalog.items : applications
      )
      self.includesSystemSettings = includesSystemSettings
    }

    calculatorResult = calculator.evaluate(query, currencyRates: currencyRates)
    filteredApplications = applicationController.ranked(query: query)
  }

  private func refreshShortcuts() {
    guard mode == .shortcuts else { return }

    filteredShortcuts = shortcutController.ranked(query: query)
  }
}

private struct ActionError {
  let mode: LauncherMode
  let message: String
}

enum LauncherEvent: Equatable {
  case calculatorResultCopied
  case emojiCopied
  case fileOpened
  case launchStarted
  case launchSucceeded
  case shortcutRunStarted

  /// Copy events leave no other app to take focus, so the launcher returns it to the previous app.
  var restoresPreviousFocus: Bool {
    switch self {
    case .calculatorResultCopied, .emojiCopied: true
    case .fileOpened, .launchStarted, .launchSucceeded, .shortcutRunStarted: false
    }
  }
}

enum LauncherResultID: Hashable {
  case application(InstalledApplication.ID)
  case calculator
  case emoji(Emoji.ID)
  case file(FileSearchResult.ID)
  case shortcut(AppleShortcut.ID)
}

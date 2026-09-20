import AppKit
import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {

  private static let emojiByValue = Dictionary(
    uniqueKeysWithValues: Emoji.catalog.map { ($0.value, $0) }
  )

  private static let skinToneVariants = Dictionary(
    uniqueKeysWithValues: Emoji.catalog.compactMap { emoji -> (String, Emoji)? in
      guard emoji.skinToneModifierNames.count == 1,
        let modifierName = emoji.skinToneModifierNames.first
      else { return nil }
      return (skinToneVariantKey(baseName: emoji.baseName, modifierName: modifierName), emoji)
    }
  )

  private static func skinToneVariantKey(baseName: String, modifierName: String) -> String {
    "\(baseName)\0\(modifierName)"
  }

  private static func emoji(for values: [String]) -> [Emoji] {
    values.compactMap { emojiByValue[$0] }
  }

  @Published var query = "" {
    didSet {
      refreshCurrentResults()
      selectFirstResult()
      if mode == .applications {
        launchErrorMessage = nil
      } else {
        shortcutRunErrorMessage = nil
      }
    }
  }

  @Published private(set) var mode = LauncherMode.applications
  @Published private(set) var applications = [InstalledApplication]()
  @Published private(set) var filteredApplications = [InstalledApplication]()
  @Published private(set) var catalogErrorMessage: String?
  @Published private(set) var isLoading = false
  @Published private(set) var launchErrorMessage: String?
  @Published private(set) var selectedApplicationID: InstalledApplication.ID?
  @Published private(set) var calculatorResult: CalculatorResult?
  @Published private(set) var isCalculatorSelected = false
  @Published private(set) var clipboardEntries = [ClipboardEntry]()
  @Published private(set) var filteredClipboardEntries = [ClipboardEntry]()
  @Published private(set) var selectedClipboardEntryID: ClipboardEntry.ID?
  @Published private(set) var shortcuts = [AppleShortcut]()
  @Published private(set) var filteredShortcuts = [AppleShortcut]()
  @Published private(set) var shortcutCatalogErrorMessage: String?
  @Published private(set) var isLoadingShortcuts = false
  @Published private(set) var shortcutRunErrorMessage: String?
  @Published private(set) var selectedShortcutID: AppleShortcut.ID?
  @Published private(set) var filteredEmoji = [Emoji]()
  @Published private(set) var recentEmoji = [Emoji]()
  @Published private(set) var selectedEmojiID: Emoji.ID?
  @Published private(set) var fileResults = [FileSearchResult]()
  @Published private(set) var isSearchingFiles = false
  @Published private(set) var fileSearchErrorMessage: String?
  @Published private(set) var selectedFileID: FileSearchResult.ID?
  @Published private(set) var selectionScrollRequest = 0
  @Published private(set) var focusRequest = 0

  var selectedResultScrollID: LauncherResultID? {
    switch mode {
    case .applications:
      isCalculatorSelected ? .calculator : selectedApplicationID.map(LauncherResultID.application)
    case .clipboard:
      selectedClipboardEntryID.map(LauncherResultID.clipboard)
    case .emoji:
      selectedEmojiID.map(LauncherResultID.emoji)
    case .files:
      selectedFileID.map(LauncherResultID.file)
    case .shortcuts:
      selectedShortcutID.map(LauncherResultID.shortcut)
    }
  }

  var displayedEmoji: [Emoji] {
    let emoji = skinToneAdjustedEmoji
    guard query.isEmpty else { return emoji }
    let recentIDs = Set(recentEmoji.map(\.id))
    return recentEmoji + emoji.filter { !recentIDs.contains($0.id) }
  }

  private let settingsStore: SettingsStore
  private let clipboardHistory: ClipboardHistory
  private let catalog: ApplicationCatalogLoading
  private let calculator: CalculatorEngine
  private let writeToClipboard: @MainActor (String) -> Void
  private let launchApplication: @MainActor (InstalledApplication) async throws -> Void
  private let shortcutCatalog: ShortcutCatalogLoading
  private let runShortcut: @MainActor (AppleShortcut) async throws -> Void
  private let emojiHistory: EmojiHistoryStore
  private let applicationController: LauncherApplicationController
  private let shortcutController: LauncherShortcutController
  private let fileController: LauncherFileController
  private let onEvent: (LauncherEvent) -> Void

  private var currencySource = CurrencySource.off
  private let applicationLoader = CatalogReloadCoordinator<InstalledApplication>()
  private let shortcutsLoader = CatalogReloadCoordinator<AppleShortcut>()
  private var applicationIndexIncludesSystemSettings: Bool?
  private var emojiIndex: EmojiRanker.Index?
  private var hasLoadedEmoji = false
  private var hasLoadedShortcuts = false
  private var runningShortcutIDs = Set<AppleShortcut.ID>()
  private var lastPointerLocation: NSPoint?

  private var selectedClipboardEntry: ClipboardEntry? {
    filteredClipboardEntries.first { $0.id == selectedClipboardEntryID }
      ?? filteredClipboardEntries.first
  }

  private var skinToneAdjustedEmoji: [Emoji] {
    guard !isExplicitSkinToneQuery else { return filteredEmoji }

    return filteredEmoji.compactMap { emoji in
      guard !emoji.hasSkinTone else { return nil }
      guard let modifierName = settingsStore.preferredEmojiSkinTone.modifierName else {
        return emoji
      }
      let variantKey = Self.skinToneVariantKey(baseName: emoji.name, modifierName: modifierName)
      return Self.skinToneVariants[variantKey] ?? emoji
    }
  }

  private var isExplicitSkinToneQuery: Bool {
    EmojiRanker.explicitlyRequestsSkinTone(query)
  }

  private var selectedApplication: InstalledApplication? {
    filteredApplications.first { $0.id == selectedApplicationID }
      ?? filteredApplications.first
  }

  private var selectedShortcut: AppleShortcut? {
    filteredShortcuts.first { $0.id == selectedShortcutID } ?? filteredShortcuts.first
  }

  private var selectedEmoji: Emoji? {
    displayedEmoji.first { $0.id == selectedEmojiID } ?? displayedEmoji.first
  }

  private var selectedFile: FileSearchResult? {
    fileResults.first { $0.id == selectedFileID } ?? fileResults.first
  }

  init(
    settingsStore: SettingsStore = SettingsStore(),
    clipboardHistory: ClipboardHistory = ClipboardHistory(),
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
    self.clipboardHistory = clipboardHistory
    self.catalog = catalog
    self.calculator = calculator
    self.writeToClipboard = writeToClipboard
    self.launchApplication = launchApplication
    self.shortcutCatalog = shortcutCatalog
    self.runShortcut = runShortcut
    self.emojiHistory = emojiHistory
    applicationController = LauncherApplicationController(history: launchHistory)
    shortcutController = LauncherShortcutController(history: shortcutRunHistory)
    fileController = LauncherFileController(searcher: fileSearcher)
    self.onEvent = onEvent
  }

  func setCurrencySource(_ source: CurrencySource) {
    guard source != currencySource else {
      return
    }
    currencySource = source
    refreshCurrentResults()
    selectFirstResult()
  }

  func updateQuery(_ value: String) {
    guard let prefix = value.first, [";", "'", ">", ":", "/"].contains(prefix) else {
      query = value
      return
    }
    if prefix == "/", !settingsStore.isFilesModuleEnabled {
      query = value
      return
    }
    let requestedMode: LauncherMode =
      switch prefix {
      case ";": .applications
      case "'": .clipboard
      case ">": .shortcuts
      case ":": .emoji
      default: .files
      }
    transition(to: requestedMode, query: String(value.dropFirst()))
  }

  func cycleMode() {
    switch mode {
    case .applications:
      transition(to: .shortcuts)
    case .shortcuts:
      transition(to: .emoji)
    case .emoji:
      if settingsStore.isFilesModuleEnabled {
        transition(to: .files)
      } else if settingsStore.isClipboardHistoryEnabled {
        transition(to: .clipboard)
      } else {
        transition(to: .applications)
      }
    case .files:
      transition(to: settingsStore.isClipboardHistoryEnabled ? .clipboard : .applications)
    case .clipboard:
      transition(to: .applications)
    }
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
          if mode == .applications { selectFirstResult() }
        case .failure(let error):
          replaceApplications(with: [])
          catalogErrorMessage =
            "Couldn’t load installed applications. \(error.localizedDescription)"
          selectedApplicationID = nil
        }
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
          if mode == .shortcuts { selectFirstResult() }
        case .failure(let error):
          hasLoadedShortcuts = false
          replaceShortcuts(with: [])
          shortcutCatalogErrorMessage = "Couldn’t load shortcuts. \(error.localizedDescription)"
          selectedShortcutID = nil
        }
      }
    )
  }

  func select(_ application: InstalledApplication) {
    isCalculatorSelected = false
    selectedApplicationID = application.id
  }

  func selectOnHover(_ application: InstalledApplication) {
    guard pointerDidMove() else {
      return
    }
    select(application)
  }

  func selectCalculatorResultOnHover() {
    guard pointerDidMove(), calculatorResult != nil else {
      return
    }
    isCalculatorSelected = true
  }

  func select(_ shortcut: AppleShortcut) {
    selectedShortcutID = shortcut.id
  }

  func select(_ entry: ClipboardEntry) {
    selectedClipboardEntryID = entry.id
  }

  func selectOnHover(_ entry: ClipboardEntry) {
    guard pointerDidMove() else { return }
    select(entry)
  }

  func selectOnHover(_ shortcut: AppleShortcut) {
    guard pointerDidMove() else {
      return
    }
    select(shortcut)
  }

  func moveSelection(_ direction: MoveCommandDirection) {
    lastPointerLocation = NSEvent.mouseLocation

    switch mode {
    case .applications:
      let applicationResultIDs = filteredApplications.map { LauncherResultID.application($0.id) }
      let resultIDs =
        calculatorResult == nil
        ? applicationResultIDs
        : [.calculator] + applicationResultIDs
      let selectedID: LauncherResultID? =
        isCalculatorSelected
        ? .calculator
        : selectedApplicationID.map(LauncherResultID.application)
      let movedID = movedSelection(
        direction,
        results: resultIDs,
        selectedID: selectedID
      )
      isCalculatorSelected = movedID == .calculator
      if case .application(let applicationID) = movedID {
        selectedApplicationID = applicationID
      }
    case .clipboard:
      selectedClipboardEntryID = movedSelection(
        direction,
        results: filteredClipboardEntries.map(\.id),
        selectedID: selectedClipboardEntryID
      )
    case .emoji:
      selectedEmojiID = movedSelection(
        direction,
        results: displayedEmoji.map(\.id),
        selectedID: selectedEmojiID,
        step: LauncherLayout.emojiColumnCount
      )
    case .files:
      selectedFileID = movedSelection(
        direction,
        results: fileResults.map(\.id),
        selectedID: selectedFileID
      )
    case .shortcuts:
      selectedShortcutID = movedSelection(
        direction,
        results: filteredShortcuts.map(\.id),
        selectedID: selectedShortcutID
      )
    }
  }

  func openSelectedResult() {
    switch mode {
    case .applications:
      if isCalculatorSelected {
        copyCalculatorResult()
      } else if let selectedApplication {
        open(selectedApplication)
      }
    case .clipboard:
      copySelectedClipboardEntry()
    case .emoji:
      copySelectedEmoji()
    case .files:
      openSelectedFile()
    case .shortcuts:
      if let selectedShortcut {
        run(selectedShortcut)
      }
    }
  }

  func open(_ application: InstalledApplication) {
    isCalculatorSelected = false
    selectedApplicationID = application.id
    launchErrorMessage = nil
    onEvent(.launchStarted)

    let launchApplication = launchApplication
    perform(
      operation: { try await launchApplication(application) },
      onSuccess: { [weak self] in
        guard let self else { return }
        applicationController.record(application)
        query = ""
        onEvent(.launchSucceeded)
      },
      onFailure: { [weak self] error in
        self?.launchErrorMessage =
          "Couldn’t open \(application.displayName). \(error.localizedDescription)"
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

  func copy(_ entry: ClipboardEntry) {
    selectedClipboardEntryID = entry.id
    writeToClipboard(entry.text)
    query = ""
    onEvent(.clipboardEntryCopied)
  }

  func copySelectedClipboardEntry() {
    guard let selectedClipboardEntry else { return }
    copy(selectedClipboardEntry)
  }

  func copySelectedClipboardEntryKeepingLauncherOpen() {
    guard let selectedClipboardEntry else { return }
    writeToClipboard(selectedClipboardEntry.text)
  }

  func deleteSelectedClipboardEntry() {
    guard let selectedClipboardEntry else { return }
    clipboardHistory.delete(selectedClipboardEntry)
    refreshClipboardEntries()
    selectFirstResult()
  }

  func clearClipboardHistory() {
    clipboardHistory.clear()
    refreshClipboardEntries()
    selectFirstResult()
  }

  func select(_ emoji: Emoji) { selectedEmojiID = emoji.id }

  func selectOnHover(_ emoji: Emoji) {
    guard pointerDidMove() else { return }
    select(emoji)
  }

  func copySelectedEmoji() {
    guard let emoji = selectedEmoji else { return }
    writeToClipboard(emoji.value)
    emojiHistory.record(emoji)
    recentEmoji = Self.emoji(for: emojiHistory.load())
    query = ""
    mode = .applications
    onEvent(.emojiCopied)
  }

  func select(_ file: FileSearchResult) {
    selectedFileID = file.id
  }

  func selectOnHover(_ file: FileSearchResult) {
    guard pointerDidMove() else { return }
    select(file)
  }

  func openSelectedFile() {
    guard let file = selectedFile else { return }
    selectedFileID = file.id
    fileSearchErrorMessage = nil
    guard NSWorkspace.shared.open(file.url) else {
      fileSearchErrorMessage = "Couldn’t open \(file.displayName). The item could not be opened."
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

    selectedShortcutID = shortcut.id
    shortcutRunErrorMessage = nil
    onEvent(.shortcutRunStarted)

    let runShortcut = runShortcut
    perform(
      operation: { try await runShortcut(shortcut) },
      onSuccess: { [weak self] in
        guard let self else { return }
        shortcutController.record(shortcut)
        runningShortcutIDs.remove(shortcut.id)
        query = ""
      },
      onFailure: { [weak self] error in
        self?.runningShortcutIDs.remove(shortcut.id)
        self?.shortcutRunErrorMessage =
          "Couldn’t run \(shortcut.name). \(error.localizedDescription)"
      }
    )
  }

  func clearActionError() {
    switch mode {
    case .applications: launchErrorMessage = nil
    case .clipboard: break
    case .emoji: break
    case .files: fileSearchErrorMessage = nil
    case .shortcuts: shortcutRunErrorMessage = nil
    }
  }

  func prepareForActivation(mode requestedMode: LauncherMode? = nil) {
    if let requestedMode {
      launchErrorMessage = nil
      shortcutRunErrorMessage = nil
      transition(to: requestedMode)
    } else if launchErrorMessage != nil {
      transition(to: .applications, query: nil)
    } else if shortcutRunErrorMessage != nil {
      transition(to: .shortcuts, query: nil)
    } else {
      launchErrorMessage = nil
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
    var mode = mode
    if mode == .files && !settingsStore.isFilesModuleEnabled { mode = .applications }
    if mode == .clipboard && !settingsStore.isClipboardHistoryEnabled { mode = .applications }
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
    switch mode {
    case .applications:
      isCalculatorSelected = calculatorResult != nil
      selectedApplicationID = filteredApplications.first?.id
    case .clipboard:
      isCalculatorSelected = false
      selectedClipboardEntryID = filteredClipboardEntries.first?.id
    case .emoji:
      isCalculatorSelected = false
      selectedEmojiID = displayedEmoji.first?.id
    case .files:
      isCalculatorSelected = false
      selectedFileID = fileResults.first?.id
    case .shortcuts:
      isCalculatorSelected = false
      selectedShortcutID = filteredShortcuts.first?.id
    }
    selectionScrollRequest &+= 1
  }

  private func replaceApplications(with applications: [InstalledApplication]) {
    self.applications = applications
    applicationIndexIncludesSystemSettings = nil
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
    case .clipboard: refreshClipboardEntries()
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
        selectedFileID = nil
        isSearchingFiles = false
      case .searching:
        isSearchingFiles = true
      case .results(let results):
        fileResults = results
        selectedFileID = results.first?.id
        isSearchingFiles = false
      case .failed(let error):
        fileResults = []
        selectedFileID = nil
        fileSearchErrorMessage = "Couldn’t search files. \(error.localizedDescription)"
        isSearchingFiles = false
      }
    }
  }

  private func refreshApplications() {
    let includesSystemSettings =
      settingsStore.showsSystemSettingsItems && !query.trimmingCharacters(in: .whitespaces).isEmpty
    if applicationIndexIncludesSystemSettings != includesSystemSettings {
      applicationController.replace(
        includesSystemSettings ? applications + SystemSettingsCatalog.items : applications
      )
      applicationIndexIncludesSystemSettings = includesSystemSettings
    }

    let result = calculator.evaluate(query, currencySource: currencySource)
    calculatorResult = mode == .applications ? result : nil
    filteredApplications = applicationController.ranked(
      query: mode == .applications ? query : ""
    )
  }

  private func refreshShortcuts() {
    filteredShortcuts = shortcutController.ranked(
      query: mode == .shortcuts ? query : ""
    )
  }

  private func refreshClipboardEntries() {
    clipboardEntries = clipboardHistory.entries
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    filteredClipboardEntries =
      normalizedQuery.isEmpty
      ? clipboardEntries
      : clipboardEntries.filter { $0.text.localizedCaseInsensitiveContains(normalizedQuery) }
  }

}

enum LauncherEvent: Equatable {
  case calculatorResultCopied
  case clipboardEntryCopied
  case emojiCopied
  case fileOpened
  case launchStarted
  case launchSucceeded
  case shortcutRunStarted
}

enum LauncherResultID: Hashable {
  case application(InstalledApplication.ID)
  case calculator
  case clipboard(ClipboardEntry.ID)
  case emoji(Emoji.ID)
  case file(FileSearchResult.ID)
  case shortcut(AppleShortcut.ID)
}

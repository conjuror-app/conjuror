import AppKit
import Foundation
import SwiftUI

enum LauncherEvent: Equatable {
  case calculatorResultCopied
  case emojiCopied
  case fileOpened
  case launchStarted
  case launchSucceeded
  case shortcutRunStarted
}

enum LauncherResultID: Hashable {
  case application(InstalledApplication.ID)
  case calculator
  case emoji(Emoji.ID)
  case file(FileSearchResult.ID)
  case shortcut(AppleShortcut.ID)
}

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
  @Published private(set) var shortcuts = [AppleShortcut]()
  @Published private(set) var filteredShortcuts = [AppleShortcut]()
  @Published private(set) var shortcutCatalogErrorMessage: String?
  @Published private(set) var isLoadingShortcuts = false
  @Published private(set) var shortcutRunErrorMessage: String?
  @Published private(set) var selectedShortcutID: AppleShortcut.ID?
  @Published private(set) var filteredEmoji = Emoji.catalog
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
  private let catalog: ApplicationCatalogLoading
  private let calculator: CalculatorEngine
  private let calculatorClipboard: CalculatorClipboardWriting
  private let launcher: ApplicationLaunching
  private let shortcutCatalog: ShortcutCatalogLoading
  private let shortcutRunner: ShortcutRunning
  private let fileOpener = FileOpener()
  private let emojiHistory: EmojiHistoryStore
  private let applicationController: LauncherApplicationController
  private let shortcutController: LauncherShortcutController
  private let fileController: LauncherFileController
  private let onEvent: (LauncherEvent) -> Void

  private var currencySource = CurrencySource.off
  private let emojiIndex = EmojiRanker.Index(emoji: Emoji.catalog)
  private let applicationLoader = CatalogReloadCoordinator<InstalledApplication>()
  private let shortcutsLoader = CatalogReloadCoordinator<AppleShortcut>()
  private var runningShortcutIDs = Set<AppleShortcut.ID>()
  private var lastPointerLocation: NSPoint?

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
    catalog: ApplicationCatalogLoading = ApplicationCatalog(),
    calculator: CalculatorEngine = CalculatorEngine(),
    calculatorClipboard: CalculatorClipboardWriting = SystemCalculatorClipboard(),
    launcher: ApplicationLaunching = ApplicationLauncher(),
    launchHistory: LaunchHistoryStore = LaunchHistoryStore(),
    shortcutCatalog: ShortcutCatalogLoading = ShortcutCatalog(),
    shortcutRunner: ShortcutRunning = ShortcutRunner(),
    shortcutRunHistory: ShortcutRunHistoryStore = ShortcutRunHistoryStore(),
    emojiHistory: EmojiHistoryStore = EmojiHistoryStore(),
    fileSearcher: FileSearching = SpotlightFileSearchService(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) {
    self.settingsStore = settingsStore
    self.catalog = catalog
    self.calculator = calculator
    self.calculatorClipboard = calculatorClipboard
    self.launcher = launcher
    self.shortcutCatalog = shortcutCatalog
    self.shortcutRunner = shortcutRunner
    self.emojiHistory = emojiHistory
    applicationController = LauncherApplicationController(history: launchHistory)
    shortcutController = LauncherShortcutController(history: shortcutRunHistory)
    fileController = LauncherFileController(searcher: fileSearcher)
    self.onEvent = onEvent
    recentEmoji = Self.emoji(for: emojiHistory.load())
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
    guard let prefix = value.first, [";", ">", ":", "/"].contains(prefix) else {
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
      transition(to: settingsStore.isFilesModuleEnabled ? .files : .applications)
    case .files:
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

    let launcher = launcher
    perform(
      operation: { try await launcher.open(application) },
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
    calculatorClipboard.write(calculatorResult.copyText)
    query = ""
    onEvent(.calculatorResultCopied)
  }

  func select(_ emoji: Emoji) { selectedEmojiID = emoji.id }

  func selectOnHover(_ emoji: Emoji) {
    guard pointerDidMove() else { return }
    select(emoji)
  }

  func copySelectedEmoji() {
    guard let emoji = selectedEmoji else { return }
    calculatorClipboard.write(emoji.value)
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
    do {
      try fileOpener.open(file.url)
      query = ""
      onEvent(.fileOpened)
    } catch {
      fileSearchErrorMessage = "Couldn’t open \(file.displayName). \(error.localizedDescription)"
    }
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

    let shortcutRunner = shortcutRunner
    perform(
      operation: { try await shortcutRunner.run(shortcut) },
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
    switch mode {
    case .applications:
      isCalculatorSelected = calculatorResult != nil
      selectedApplicationID = filteredApplications.first?.id
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
    applicationController.replace(applications)
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
    case .emoji: filteredEmoji = emojiIndex.ranked(query: query)
    case .files: searchFiles()
    case .shortcuts: refreshShortcuts()
    }
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
    let searchableApplications =
      settingsStore.showsSystemSettingsItems && !query.trimmingCharacters(in: .whitespaces).isEmpty
      ? applications + SystemSettingsCatalog.items
      : applications
    applicationController.replace(searchableApplications)

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

}

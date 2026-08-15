import AppKit
import Foundation
import SwiftUI

enum LauncherEvent: Equatable {
  case calculatorResultCopied
  case emojiCopied
  case launchStarted
  case launchSucceeded
  case shortcutRunStarted
}

enum LauncherResultID: Hashable {
  case application(InstalledApplication.ID)
  case calculator
  case emoji(Emoji.ID)
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

  @Published private(set) var selectionScrollRequest = 0
  @Published private(set) var focusRequest = 0

  var selectedResultScrollID: LauncherResultID? {
    switch mode {
    case .applications:
      isCalculatorSelected ? .calculator : selectedApplicationID.map(LauncherResultID.application)
    case .emoji:
      selectedEmojiID.map(LauncherResultID.emoji)
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
  private let calculator: CalculatorEvaluating
  private let calculatorClipboard: CalculatorClipboardWriting
  private let launcher: ApplicationLaunching
  private let launchHistory: LaunchHistoryStore
  private let shortcutCatalog: ShortcutCatalogLoading
  private let shortcutRunner: ShortcutRunning
  private let shortcutRunHistory: ShortcutRunHistoryStore
  private let emojiHistory: EmojiHistoryStore
  private let onEvent: (LauncherEvent) -> Void

  private var recentLaunches: [String: Date]
  private var recentShortcutRuns: [String: Date]
  private var currencySource = CurrencySource.off
  private var applicationIndex = ApplicationRanker.Index(applications: [])
  private var shortcutIndex = ShortcutRanker.Index(shortcuts: [])
  private let emojiIndex = EmojiRanker.Index(emoji: Emoji.catalog)
  private var loadTask: Task<Void, Never>?
  private var shortcutLoadTask: Task<Void, Never>?
  private var reloadRequested = false
  private var shortcutReloadRequested = false
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

  init(
    settingsStore: SettingsStore = SettingsStore(),
    catalog: ApplicationCatalogLoading = ApplicationCatalog(),
    calculator: CalculatorEvaluating = CalculatorEngine(),
    calculatorClipboard: CalculatorClipboardWriting = SystemCalculatorClipboard(),
    launcher: ApplicationLaunching = ApplicationLauncher(),
    launchHistory: LaunchHistoryStore = LaunchHistoryStore(),
    shortcutCatalog: ShortcutCatalogLoading = ShortcutCatalog(),
    shortcutRunner: ShortcutRunning = ShortcutRunner(),
    shortcutRunHistory: ShortcutRunHistoryStore = ShortcutRunHistoryStore(),
    emojiHistory: EmojiHistoryStore = EmojiHistoryStore(),
    onEvent: @escaping (LauncherEvent) -> Void = { _ in }
  ) {
    self.settingsStore = settingsStore
    self.catalog = catalog
    self.calculator = calculator
    self.calculatorClipboard = calculatorClipboard
    self.launcher = launcher
    self.launchHistory = launchHistory
    self.shortcutCatalog = shortcutCatalog
    self.shortcutRunner = shortcutRunner
    self.shortcutRunHistory = shortcutRunHistory
    self.emojiHistory = emojiHistory
    self.onEvent = onEvent
    recentLaunches = launchHistory.load()
    recentShortcutRuns = shortcutRunHistory.load()
    recentEmoji = Self.emoji(for: emojiHistory.load())
  }

  deinit {
    loadTask?.cancel()
    shortcutLoadTask?.cancel()
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
    guard let prefix = value.first, [";", ">", ":"].contains(prefix) else {
      query = value
      return
    }
    let requestedMode: LauncherMode =
      switch prefix {
      case ";": .applications
      case ">": .shortcuts
      default: .emoji
      }
    transition(to: requestedMode, query: String(value.dropFirst()))
  }

  func cycleMode() {
    switch mode {
    case .applications:
      enterShortcutsMode()
    case .shortcuts:
      transition(to: .emoji)
    case .emoji:
      returnToApplicationsMode()
    }
  }

  func enterShortcutsMode() {
    transition(to: .shortcuts)
  }

  func returnToApplicationsMode() {
    transition(to: .applications)
  }

  func loadApplications() {
    guard !isLoading else {
      reloadRequested = true
      return
    }

    isLoading = true
    catalogErrorMessage = nil

    let catalog = catalog
    loadTask = Task { [weak self] in
      do {
        let loadedApplications = try await catalog.load()
        guard let self, !Task.isCancelled else {
          return
        }
        replaceApplications(with: loadedApplications)
        if mode == .applications {
          selectFirstResult()
        }
        finishLoadingApplications()
      } catch is CancellationError {
        self?.finishLoadingApplications()
      } catch {
        guard let self else {
          return
        }
        replaceApplications(with: [])
        catalogErrorMessage = "Couldn’t load installed applications. \(error.localizedDescription)"
        selectedApplicationID = nil
        finishLoadingApplications()
      }
    }
  }

  func loadShortcuts() {
    guard !isLoadingShortcuts else {
      shortcutReloadRequested = true
      return
    }

    isLoadingShortcuts = true
    shortcutCatalogErrorMessage = nil

    let shortcutCatalog = shortcutCatalog
    shortcutLoadTask = Task { [weak self] in
      do {
        let loadedShortcuts = try await shortcutCatalog.load()
        guard let self, !Task.isCancelled else {
          return
        }
        replaceShortcuts(with: loadedShortcuts)
        if mode == .shortcuts {
          selectFirstResult()
        }
        finishLoadingShortcuts()
      } catch is CancellationError {
        self?.finishLoadingShortcuts()
      } catch {
        guard let self else {
          return
        }
        replaceShortcuts(with: [])
        shortcutCatalogErrorMessage = "Couldn’t load shortcuts. \(error.localizedDescription)"
        selectedShortcutID = nil
        finishLoadingShortcuts()
      }
    }
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

  func selectCalculatorResult() {
    guard calculatorResult != nil else {
      return
    }
    isCalculatorSelected = true
  }

  func selectCalculatorResultOnHover() {
    guard pointerDidMove() else {
      return
    }
    selectCalculatorResult()
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
      } else {
        openSelectedApplication()
      }
    case .emoji:
      copySelectedEmoji()
    case .shortcuts:
      runSelectedShortcut()
    }
  }

  func openSelectedApplication() {
    guard let application = selectedApplication else {
      return
    }
    open(application)
  }

  func open(_ application: InstalledApplication) {
    isCalculatorSelected = false
    selectedApplicationID = application.id
    launchErrorMessage = nil
    onEvent(.launchStarted)

    let launcher = launcher
    Task { [weak self] in
      do {
        try await launcher.open(application)
        guard let self else {
          return
        }
        launchHistory.recordLaunch(of: application)
        recentLaunches = launchHistory.load()
        query = ""
        onEvent(.launchSucceeded)
      } catch {
        self?.launchErrorMessage =
          "Couldn’t open \(application.displayName). \(error.localizedDescription)"
      }
    }
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

  func runSelectedShortcut() {
    guard let shortcut = selectedShortcut else {
      return
    }
    run(shortcut)
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
    Task { [weak self] in
      do {
        try await shortcutRunner.run(shortcut)
        guard let self else {
          return
        }
        shortcutRunHistory.recordRun(of: shortcut)
        recentShortcutRuns = shortcutRunHistory.load()
        runningShortcutIDs.remove(shortcut.id)
        query = ""
      } catch {
        self?.runningShortcutIDs.remove(shortcut.id)
        self?.shortcutRunErrorMessage =
          "Couldn’t run \(shortcut.name). \(error.localizedDescription)"
      }
    }
  }

  func clearLaunchError() {
    launchErrorMessage = nil
  }

  func clearShortcutRunError() {
    shortcutRunErrorMessage = nil
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

  private func transition(to mode: LauncherMode, query: String? = "") {
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
    case .shortcuts:
      isCalculatorSelected = false
      selectedShortcutID = filteredShortcuts.first?.id
    }
    selectionScrollRequest &+= 1
  }

  private func replaceApplications(with applications: [InstalledApplication]) {
    self.applications = applications
    applicationIndex = ApplicationRanker.Index(applications: applications)
    refreshApplications()
  }

  private func replaceShortcuts(with shortcuts: [AppleShortcut]) {
    self.shortcuts = shortcuts
    shortcutIndex = ShortcutRanker.Index(shortcuts: shortcuts)
    refreshShortcuts()
  }

  private func refreshCurrentResults() {
    calculatorResult = nil
    switch mode {
    case .applications: refreshApplications()
    case .emoji: filteredEmoji = emojiIndex.ranked(query: query)
    case .shortcuts: refreshShortcuts()
    }
  }

  private func refreshApplications() {
    let result: CalculatorResult?
    if let currencyCalculator = calculator as? CurrencyCalculatorEvaluating {
      result = currencyCalculator.evaluate(query, currencySource: currencySource)
    } else {
      result = calculator.evaluate(query)
    }
    calculatorResult = mode == .applications ? result : nil
    filteredApplications = applicationIndex.ranked(
      query: mode == .applications ? query : "",
      recentLaunches: recentLaunches
    )
  }

  private func refreshShortcuts() {
    filteredShortcuts = shortcutIndex.ranked(
      query: mode == .shortcuts ? query : "",
      recentRuns: recentShortcutRuns
    )
  }

  private func finishLoadingApplications() {
    isLoading = false
    loadTask = nil
    guard reloadRequested else {
      return
    }
    reloadRequested = false
    loadApplications()
  }

  private func finishLoadingShortcuts() {
    isLoadingShortcuts = false
    shortcutLoadTask = nil
    guard shortcutReloadRequested else {
      return
    }
    shortcutReloadRequested = false
    loadShortcuts()
  }
}

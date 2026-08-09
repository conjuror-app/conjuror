import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    static let calculatorResultScrollID = "calculator-result"

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

    @Published private(set) var selectionScrollRequest = 0
    @Published private(set) var focusRequest = 0

    private let catalog: ApplicationCatalogLoading
    private let calculator: CalculatorEvaluating
    private let calculatorClipboard: CalculatorClipboardWriting
    private let launcher: ApplicationLaunching
    private let launchHistory: LaunchHistoryStore
    private let shortcutCatalog: ShortcutCatalogLoading
    private let shortcutRunner: ShortcutRunning
    private let shortcutRunHistory: ShortcutRunHistoryStore
    private let onLaunchSuccess: () -> Void
    private let onCalculatorResultCopied: () -> Void
    private let onShortcutRunStarted: () -> Void

    private var recentLaunches: [String: Date]
    private var recentShortcutRuns: [String: Date]
    private var applicationIndex = ApplicationRanker.Index(applications: [])
    private var shortcutIndex = ShortcutRanker.Index(shortcuts: [])
    private var loadTask: Task<Void, Never>?
    private var shortcutLoadTask: Task<Void, Never>?
    private var reloadRequested = false
    private var shortcutReloadRequested = false
    private var runningShortcutIDs = Set<AppleShortcut.ID>()

    private var selectedApplication: InstalledApplication? {
        filteredApplications.first { $0.id == selectedApplicationID }
            ?? filteredApplications.first
    }

    private var selectedShortcut: AppleShortcut? {
        filteredShortcuts.first { $0.id == selectedShortcutID }
            ?? filteredShortcuts.first
    }

    var selectedResultScrollID: String? {
        switch mode {
        case .applications:
            isCalculatorSelected
                ? Self.calculatorResultScrollID
                : selectedApplicationID
        case .shortcuts:
            selectedShortcutID
        }
    }

    init(
        catalog: ApplicationCatalogLoading = ApplicationCatalog(),
        calculator: CalculatorEvaluating = CalculatorEngine(),
        calculatorClipboard: CalculatorClipboardWriting = SystemCalculatorClipboard(),
        launcher: ApplicationLaunching = ApplicationLauncher(),
        launchHistory: LaunchHistoryStore = LaunchHistoryStore(),
        shortcutCatalog: ShortcutCatalogLoading = ShortcutCatalog(),
        shortcutRunner: ShortcutRunning = ShortcutRunner(),
        shortcutRunHistory: ShortcutRunHistoryStore = ShortcutRunHistoryStore(),
        onLaunchSuccess: @escaping () -> Void = {},
        onCalculatorResultCopied: @escaping () -> Void = {},
        onShortcutRunStarted: @escaping () -> Void = {}
    ) {
        self.catalog = catalog
        self.calculator = calculator
        self.calculatorClipboard = calculatorClipboard
        self.launcher = launcher
        self.launchHistory = launchHistory
        self.shortcutCatalog = shortcutCatalog
        self.shortcutRunner = shortcutRunner
        self.shortcutRunHistory = shortcutRunHistory
        self.onLaunchSuccess = onLaunchSuccess
        self.onCalculatorResultCopied = onCalculatorResultCopied
        self.onShortcutRunStarted = onShortcutRunStarted
        recentLaunches = launchHistory.load()
        recentShortcutRuns = shortcutRunHistory.load()
    }

    deinit {
        loadTask?.cancel()
        shortcutLoadTask?.cancel()
    }

    func updateQuery(_ value: String) {
        guard mode == .applications, value.hasPrefix(">") else {
            query = value
            return
        }

        mode = .shortcuts
        query = String(value.dropFirst())
        loadShortcuts()
    }

    func toggleMode() {
        if mode == .applications {
            enterShortcutsMode()
        } else {
            returnToApplicationsMode()
        }
    }

    func enterShortcutsMode() {
        mode = .shortcuts
        query = ""
        shortcutRunErrorMessage = nil
        refreshCurrentResults()
        selectFirstResult()
        loadShortcuts()
    }

    func returnToApplicationsMode() {
        mode = .applications
        query = ""
        refreshCurrentResults()
        selectFirstResult()
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

    func selectCalculatorResult() {
        guard calculatorResult != nil else {
            return
        }
        isCalculatorSelected = true
    }

    func select(_ shortcut: AppleShortcut) {
        selectedShortcutID = shortcut.id
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        switch mode {
        case .applications:
            let applicationResultIDs = filteredApplications.map(\.id)
            let resultIDs = calculatorResult == nil
                ? applicationResultIDs
                : [Self.calculatorResultScrollID] + applicationResultIDs
            let selectedID = isCalculatorSelected
                ? Self.calculatorResultScrollID
                : selectedApplicationID
            let movedID = movedSelection(
                direction,
                results: resultIDs,
                selectedID: selectedID
            )
            isCalculatorSelected = movedID == Self.calculatorResultScrollID
            if !isCalculatorSelected {
                selectedApplicationID = movedID
            }
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

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await launcher.open(application)
                launchHistory.recordLaunch(of: application)
                recentLaunches = launchHistory.load()
                query = ""
                onLaunchSuccess()
            } catch {
                launchErrorMessage = "Couldn’t open \(application.displayName). \(error.localizedDescription)"
            }
        }
    }

    func copyCalculatorResult() {
        guard let calculatorResult else {
            return
        }
        calculatorClipboard.write(calculatorResult.copyText)
        query = ""
        onCalculatorResultCopied()
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
        onShortcutRunStarted()

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await shortcutRunner.run(shortcut)
                shortcutRunHistory.recordRun(of: shortcut)
                recentShortcutRuns = shortcutRunHistory.load()
                runningShortcutIDs.remove(shortcut.id)
                query = ""
            } catch {
                runningShortcutIDs.remove(shortcut.id)
                shortcutRunErrorMessage = "Couldn’t run \(shortcut.name). \(error.localizedDescription)"
            }
        }
    }

    func clearLaunchError() {
        launchErrorMessage = nil
    }

    func clearShortcutRunError() {
        shortcutRunErrorMessage = nil
    }

    func prepareForActivation() {
        if shortcutRunErrorMessage != nil {
            mode = .shortcuts
            refreshCurrentResults()
            selectFirstResult()
            loadShortcuts()
        } else {
            mode = .applications
            query = ""
            launchErrorMessage = nil
            selectFirstResult()
        }
        focusRequest &+= 1
    }

    private func movedSelection(
        _ direction: MoveCommandDirection,
        results: [String],
        selectedID: String?
    ) -> String? {
        guard !results.isEmpty else {
            return nil
        }

        let currentIndex = results.firstIndex(of: selectedID ?? "") ?? 0
        let nextIndex: Int
        switch direction {
        case .down:
            nextIndex = min(currentIndex + 1, results.count - 1)
        case .up:
            nextIndex = max(currentIndex - 1, 0)
        default:
            return selectedID
        }

        selectionScrollRequest &+= 1
        return results[nextIndex]
    }

    private func selectFirstResult() {
        if mode == .applications {
            isCalculatorSelected = calculatorResult != nil
            selectedApplicationID = filteredApplications.first?.id
        } else {
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
        if mode == .applications {
            refreshApplications()
        } else {
            calculatorResult = nil
            refreshShortcuts()
        }
    }

    private func refreshApplications() {
        calculatorResult = mode == .applications
            ? calculator.evaluate(query)
            : nil
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

enum LauncherMode: Equatable, Sendable {
    case applications
    case shortcuts
}

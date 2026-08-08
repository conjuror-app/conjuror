import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published var query = "" {
        didSet {
            refreshFilteredApplications()
            selectFirstResult()
            launchErrorMessage = nil
        }
    }

    @Published private(set) var applications = [InstalledApplication]()
    @Published private(set) var filteredApplications = [InstalledApplication]()
    @Published private(set) var catalogErrorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var launchErrorMessage: String?
    @Published private(set) var selectedApplicationID: InstalledApplication.ID?
    @Published private(set) var selectionScrollRequest = 0
    @Published private(set) var focusRequest = 0

    private let catalog: ApplicationCatalogLoading
    private let launcher: ApplicationLaunching
    private let launchHistory: LaunchHistoryStore
    private let onLaunchSuccess: () -> Void
    private var recentLaunches: [String: Date]
    private var applicationIndex = ApplicationRanker.Index(applications: [])
    private var loadTask: Task<Void, Never>?
    private var reloadRequested = false
    private var selectedApplication: InstalledApplication? {
        filteredApplications.first { $0.id == selectedApplicationID }
            ?? filteredApplications.first
    }

    init(
        catalog: ApplicationCatalogLoading = ApplicationCatalog(),
        launcher: ApplicationLaunching = ApplicationLauncher(),
        launchHistory: LaunchHistoryStore = LaunchHistoryStore(),
        onLaunchSuccess: @escaping () -> Void = {}
    ) {
        self.catalog = catalog
        self.launcher = launcher
        self.launchHistory = launchHistory
        self.onLaunchSuccess = onLaunchSuccess
        recentLaunches = launchHistory.load()
    }

    deinit {
        loadTask?.cancel()
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
                selectFirstResult()
                finishLoading()
            } catch is CancellationError {
                self?.finishLoading()
            } catch {
                guard let self else {
                    return
                }
                replaceApplications(with: [])
                catalogErrorMessage = "Couldn’t load installed applications. \(error.localizedDescription)"
                selectedApplicationID = nil
                finishLoading()
            }
        }
    }

    func select(_ application: InstalledApplication) {
        selectedApplicationID = application.id
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        let results = filteredApplications
        guard !results.isEmpty else {
            return
        }

        let currentIndex = results.firstIndex { $0.id == selectedApplicationID } ?? 0
        let nextIndex: Int

        switch direction {
        case .down:
            nextIndex = min(currentIndex + 1, results.count - 1)
        case .up:
            nextIndex = max(currentIndex - 1, 0)
        default:
            return
        }

        selectedApplicationID = results[nextIndex].id
        selectionScrollRequest &+= 1
    }

    func openSelectedApplication() {
        guard let application = selectedApplication else {
            return
        }

        open(application)
    }

    func open(_ application: InstalledApplication) {
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

    func clearLaunchError() {
        launchErrorMessage = nil
    }

    func prepareForActivation() {
        query = ""
        launchErrorMessage = nil
        selectFirstResult()
        focusRequest &+= 1
    }

    private func selectFirstResult() {
        selectedApplicationID = filteredApplications.first?.id
        selectionScrollRequest &+= 1
    }

    private func replaceApplications(with applications: [InstalledApplication]) {
        self.applications = applications
        applicationIndex = ApplicationRanker.Index(applications: applications)
        refreshFilteredApplications()
    }

    private func refreshFilteredApplications() {
        filteredApplications = applicationIndex.ranked(
            query: query,
            recentLaunches: recentLaunches
        )
    }

    private func finishLoading() {
        isLoading = false
        loadTask = nil

        guard reloadRequested else {
            return
        }

        reloadRequested = false
        loadApplications()
    }
}

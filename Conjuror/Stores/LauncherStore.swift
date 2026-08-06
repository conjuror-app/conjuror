import Foundation
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published var query = "" {
        didSet {
            selectFirstResult()
            launchErrorMessage = nil
        }
    }

    @Published private(set) var applications = [InstalledApplication]()
    @Published private(set) var catalogErrorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var launchErrorMessage: String?
    @Published private(set) var selectedApplicationID: InstalledApplication.ID?
    @Published private(set) var selectionScrollRequest = 0
    @Published private(set) var focusRequest = 0

    var filteredApplications: [InstalledApplication] {
        ApplicationRanker.ranked(
            applications: applications,
            query: query,
            recentLaunches: recentLaunches
        )
    }

    private let catalog: ApplicationCatalogLoading
    private let launcher: ApplicationLaunching
    private let launchHistory: LaunchHistoryStore
    private let onLaunchSuccess: () -> Void
    private var recentLaunches: [String: Date]
    private var loadTask: Task<Void, Never>?

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
            return
        }

        isLoading = true
        catalogErrorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let loadedApplications = try await catalog.load()
                guard !Task.isCancelled else {
                    return
                }
                applications = loadedApplications
                isLoading = false
                selectFirstResult()
            } catch is CancellationError {
                isLoading = false
            } catch {
                applications = []
                isLoading = false
                catalogErrorMessage = "Couldn’t load installed applications. \(error.localizedDescription)"
                selectedApplicationID = nil
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

    private var selectedApplication: InstalledApplication? {
        filteredApplications.first { $0.id == selectedApplicationID }
            ?? filteredApplications.first
    }

    private func selectFirstResult() {
        selectedApplicationID = filteredApplications.first?.id
        selectionScrollRequest &+= 1
    }
}

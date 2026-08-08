import AppKit
import XCTest
@testable import Conjuror

@MainActor
final class LauncherStoreTests: XCTestCase {
    func testArrowNavigationMovesSelectionDownAndUp() async {
        let applications = [
            application("Alpha", id: "dev.example.alpha"),
            application("Beta", id: "dev.example.beta"),
            application("Gamma", id: "dev.example.gamma"),
        ]
        let store = LauncherStore(
            catalog: CatalogStub(applications: applications),
            launcher: LauncherStub(),
            launchHistory: LaunchHistoryStore(
                userDefaults: UserDefaults(suiteName: #function)!
            )
        )

        store.loadApplications()
        while store.isLoading {
            await Task.yield()
        }

        XCTAssertEqual(store.selectedApplicationID, applications[0].id)

        let scrollRequestAfterLoad = store.selectionScrollRequest
        store.select(applications[1])
        XCTAssertEqual(store.selectionScrollRequest, scrollRequestAfterLoad)
        store.select(applications[0])

        store.moveSelection(.down)
        XCTAssertNotEqual(store.selectionScrollRequest, scrollRequestAfterLoad)
        XCTAssertEqual(store.selectedApplicationID, applications[1].id)

        store.moveSelection(.up)
        XCTAssertEqual(store.selectedApplicationID, applications[0].id)
    }

    func testLoadRequestDuringActiveLoadRunsOneFollowUpRefresh() async {
        let firstApplications = [application("Alpha", id: "dev.example.alpha")]
        let refreshedApplications = [application("Beta", id: "dev.example.beta")]
        let catalog = ControlledCatalog()
        let store = LauncherStore(
            catalog: catalog,
            launcher: LauncherStub(),
            launchHistory: LaunchHistoryStore(
                userDefaults: UserDefaults(suiteName: #function)!
            )
        )

        store.loadApplications()
        await catalog.waitForLoadCount(1)

        store.loadApplications()
        store.loadApplications()
        await catalog.resumeNext(returning: firstApplications)
        await catalog.waitForLoadCount(2)

        XCTAssertTrue(store.isLoading)
        await catalog.resumeNext(returning: refreshedApplications)
        while store.isLoading {
            await Task.yield()
        }

        let loadCount = await catalog.loadCount
        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(store.applications, refreshedApplications)
        XCTAssertEqual(store.selectedApplicationID, refreshedApplications[0].id)
    }

    private func application(_ name: String, id: String) -> InstalledApplication {
        InstalledApplication(
            displayName: name,
            bundleIdentifier: id,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            icon: NSImage(size: NSSize(width: 32, height: 32))
        )
    }
}

private struct CatalogStub: ApplicationCatalogLoading {
    let applications: [InstalledApplication]

    func load() async throws -> [InstalledApplication] {
        applications
    }
}

private struct LauncherStub: ApplicationLaunching {
    func open(_ application: InstalledApplication) async throws {}
}

private actor ControlledCatalog: ApplicationCatalogLoading {
    private(set) var loadCount = 0
    private var continuations = [CheckedContinuation<[InstalledApplication], Error>]()

    func load() async throws -> [InstalledApplication] {
        loadCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext(returning applications: [InstalledApplication]) {
        continuations.removeFirst().resume(returning: applications)
    }

    func waitForLoadCount(_ expectedCount: Int) async {
        while loadCount < expectedCount {
            await Task.yield()
        }
    }
}

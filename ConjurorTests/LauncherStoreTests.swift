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

        store.moveSelection(.down)
        XCTAssertEqual(store.selectedApplicationID, applications[1].id)

        store.moveSelection(.up)
        XCTAssertEqual(store.selectedApplicationID, applications[0].id)
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

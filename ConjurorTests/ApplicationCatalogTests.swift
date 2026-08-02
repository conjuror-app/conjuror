import Foundation
import XCTest
@testable import Conjuror

final class ApplicationCatalogTests: XCTestCase {
    func testFiltersHelpersBackgroundAppsAndConjuror() {
        let candidates = [
            candidate("Visible", id: "dev.example.visible", path: "/Applications/Visible.app"),
            candidate("Helper", id: "dev.example.helper", path: "/Applications/Helper.app", isHelper: true),
            candidate("Agent", id: "dev.example.agent", path: "/Applications/Agent.app", isBackgroundOnly: true),
            candidate("Conjuror", id: "dev.tombell.conjuror", path: "/Applications/Conjuror.app"),
        ]

        let result = ApplicationCatalog.filteredAndDeduplicated(
            candidates,
            excludingBundleIdentifier: "dev.tombell.conjuror"
        )

        XCTAssertEqual(result.map(\.displayName), ["Visible"])
    }

    func testDeduplicatesByBundleIdentifierAndCanonicalURL() {
        let candidates = [
            candidate("Beta Copy", id: "dev.example.beta", path: "/System/Applications/Beta.app", priority: 1),
            candidate("Beta", id: "dev.example.beta", path: "/Applications/Beta.app", priority: 0),
            candidate("Path Copy", id: nil, path: "/Applications/Path.app/../Path.app", priority: 1),
            candidate("Path", id: nil, path: "/Applications/Path.app", priority: 0),
        ]

        let result = ApplicationCatalog.filteredAndDeduplicated(
            candidates,
            excludingBundleIdentifier: nil
        )

        XCTAssertEqual(result.map(\.displayName), ["Beta", "Path"])
    }

    private func candidate(
        _ name: String,
        id: String?,
        path: String,
        priority: Int = 0,
        isBackgroundOnly: Bool = false,
        isHelper: Bool = false
    ) -> ApplicationCatalogCandidate {
        ApplicationCatalogCandidate(
            displayName: name,
            bundleIdentifier: id,
            url: URL(fileURLWithPath: path),
            sourcePriority: priority,
            isBackgroundOnly: isBackgroundOnly,
            isHelper: isHelper
        )
    }
}

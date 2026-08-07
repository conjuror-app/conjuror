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

    func testScansTopLevelSymlinkedApplications() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let applicationsDirectory = temporaryDirectory
            .appendingPathComponent("Applications", isDirectory: true)
        let appURL = temporaryDirectory
            .appendingPathComponent("Safari.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleIdentifier": "com.apple.Safari",
            "CFBundleName": "Safari",
            "CFBundlePackageType": "APPL",
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))
        let symlinkURL = applicationsDirectory.appendingPathComponent("Safari.app")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: appURL)
        try fileManager.setAttributes(
            [.extensionHidden: true],
            ofItemAtPath: symlinkURL.path
        )

        let candidates = try ApplicationCatalog.scan(directories: [applicationsDirectory])
        let result = ApplicationCatalog.filteredAndDeduplicated(
            candidates,
            excludingBundleIdentifier: nil
        )

        XCTAssertEqual(result.map(\.displayName), ["Safari"])
        XCTAssertEqual(result.first?.bundleIdentifier, "com.apple.Safari")
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

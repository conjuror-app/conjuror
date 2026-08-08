import AppKit
import XCTest
@testable import Conjuror

final class ApplicationRankerTests: XCTestCase {
    func testOrdersExactPrefixTokenAcronymAndSubstringMatches() {
        let applications = [
            application("Code Runner", id: "dev.example.substring"),
            application("Visual Studio Code", id: "dev.example.acronym"),
            application("Studio Code", id: "dev.example.token"),
            application("CodeBox", id: "dev.example.prefix"),
            application("Code", id: "dev.example.exact"),
        ]

        let result = ApplicationRanker.ranked(
            applications: applications,
            query: "code",
            recentLaunches: [:]
        )

        XCTAssertEqual(
            result.map(\.displayName),
            ["Code", "Code Runner", "CodeBox", "Studio Code", "Visual Studio Code"]
        )
    }

    func testAcronymMatchesAfterTokenMatches() {
        let applications = [
            application("Very Special Code", id: "dev.example.acronym"),
            application("My VS Code", id: "dev.example.tokens"),
        ]

        let result = ApplicationRanker.ranked(
            applications: applications,
            query: "vs",
            recentLaunches: [:]
        )

        XCTAssertEqual(result.map(\.displayName), ["My VS Code", "Very Special Code"])
    }

    func testFuzzySubsequenceMatchesApplicationName() {
        let applications = [
            application("Xylophone", id: "dev.example.xylophone"),
            application("Xcode", id: "com.apple.dt.Xcode"),
        ]

        let result = ApplicationRanker.ranked(
            applications: applications,
            query: "xcd",
            recentLaunches: [:]
        )

        XCTAssertEqual(result.map(\.displayName), ["Xcode"])
    }

    func testCompactFuzzyMatchesRankFirst() {
        let applications = [
            application("Xylocardial", id: "dev.example.spread"),
            application("Xcode", id: "com.apple.dt.Xcode"),
        ]

        let result = ApplicationRanker.ranked(
            applications: applications,
            query: "xcd",
            recentLaunches: [:]
        )

        XCTAssertEqual(result.map(\.displayName), ["Xcode", "Xylocardial"])
    }

    func testRecentSuccessfulLaunchBreaksEqualMatchTies() {
        let older = application("Alpha Editor", id: "dev.example.alpha")
        let newer = application("Atlas Editor", id: "dev.example.atlas")

        let result = ApplicationRanker.ranked(
            applications: [older, newer],
            query: "a",
            recentLaunches: [
                older.persistenceKey: Date(timeIntervalSince1970: 10),
                newer.persistenceKey: Date(timeIntervalSince1970: 20),
            ]
        )

        XCTAssertEqual(result.map(\.displayName), ["Atlas Editor", "Alpha Editor"])
    }

    func testStableNameAndPathOrderingWithoutRecency() {
        let applications = [
            application("Zulu", id: nil, path: "/Applications/Zulu-B.app"),
            application("Alpha", id: nil, path: "/Applications/Alpha.app"),
            application("Zulu", id: nil, path: "/Applications/Zulu-A.app"),
        ]

        let result = ApplicationRanker.ranked(
            applications: applications,
            query: "",
            recentLaunches: [:]
        )

        XCTAssertEqual(result.map(\.url.path), [
            "/Applications/Alpha.app",
            "/Applications/Zulu-A.app",
            "/Applications/Zulu-B.app",
        ])
    }

    func testReusableIndexMatchesOneShotRankingAcrossQueries() {
        let applications = [
            application("Visual Studio Code", id: "com.microsoft.VSCode"),
            application("Xcode", id: "com.apple.dt.Xcode"),
            application("Code Runner", id: "dev.example.runner"),
        ]
        let recentLaunches = [
            applications[1].persistenceKey: Date(timeIntervalSince1970: 20),
        ]
        let index = ApplicationRanker.Index(applications: applications)

        for query in ["", "code", "vs", "xcd", "missing"] {
            XCTAssertEqual(
                index.ranked(query: query, recentLaunches: recentLaunches),
                ApplicationRanker.ranked(
                    applications: applications,
                    query: query,
                    recentLaunches: recentLaunches
                )
            )
        }
    }

    private func application(
        _ name: String,
        id: String?,
        path: String? = nil
    ) -> InstalledApplication {
        InstalledApplication(
            displayName: name,
            bundleIdentifier: id,
            url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"),
            icon: NSImage(size: NSSize(width: 32, height: 32))
        )
    }
}

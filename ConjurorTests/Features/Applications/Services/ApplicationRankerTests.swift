import AppKit
import Testing

@testable import Conjuror

@Suite("Application Ranker")
struct ApplicationRankerTests {
  @Test("Application ranking: exact-prefix, token, acronym, and substring matches are ordered")
  func testOrdersExactPrefixTokenAcronymAndSubstringMatches() {
    let applications = [
      application("Code Runner", id: "dev.example.substring"),
      application("Visual Studio Code", id: "dev.example.acronym"),
      application("Studio Code", id: "dev.example.token"),
      application("CodeBox", id: "dev.example.prefix"),
      application("Code", id: "dev.example.exact"),
    ]

    let result = ApplicationRanker.Index(applications: applications).ranked(
      query: "code",
      recentLaunches: [:]
    )

    #expect(
      result.map(\.displayName) == [
        "Code", "Code Runner", "CodeBox", "Studio Code", "Visual Studio Code",
      ]
    )
  }

  @Test("Application ranking: acronym matches follow token matches")
  func testAcronymMatchesAfterTokenMatches() {
    let applications = [
      application("Very Special Code", id: "dev.example.acronym"),
      application("My VS Code", id: "dev.example.tokens"),
    ]

    let result = ApplicationRanker.Index(applications: applications).ranked(
      query: "vs",
      recentLaunches: [:]
    )

    #expect(result.map(\.displayName) == ["My VS Code", "Very Special Code"])
  }

  @Test("Application ranking: fuzzy subsequences match application names")
  func testFuzzySubsequenceMatchesApplicationName() {
    let applications = [
      application("Xylophone", id: "dev.example.xylophone"),
      application("Xcode", id: "com.apple.dt.Xcode"),
    ]

    let result = ApplicationRanker.Index(applications: applications).ranked(
      query: "xcd",
      recentLaunches: [:]
    )

    #expect(result.map(\.displayName) == ["Xcode"])
  }

  @Test("Application ranking: compact fuzzy matches rank first")
  func testCompactFuzzyMatchesRankFirst() {
    let applications = [
      application("Xylocardial", id: "dev.example.spread"),
      application("Xcode", id: "com.apple.dt.Xcode"),
    ]

    let result = ApplicationRanker.Index(applications: applications).ranked(
      query: "xcd",
      recentLaunches: [:]
    )

    #expect(result.map(\.displayName) == ["Xcode", "Xylocardial"])
  }

  @Test("Application ranking: recent successful launches break equal-match ties")
  func testRecentSuccessfulLaunchBreaksEqualMatchTies() {
    let older = application("Alpha Editor", id: "dev.example.alpha")
    let newer = application("Atlas Editor", id: "dev.example.atlas")

    let result = ApplicationRanker.Index(applications: [older, newer]).ranked(
      query: "a",
      recentLaunches: [
        older.persistenceKey: Date(timeIntervalSince1970: 10),
        newer.persistenceKey: Date(timeIntervalSince1970: 20),
      ]
    )

    #expect(result.map(\.displayName) == ["Atlas Editor", "Alpha Editor"])
  }

  @Test("Application ranking: names and paths provide stable ordering without recency")
  func testStableNameAndPathOrderingWithoutRecency() {
    let applications = [
      application("Zulu", id: nil, path: "/Applications/Zulu-B.app"),
      application("Alpha", id: nil, path: "/Applications/Alpha.app"),
      application("Zulu", id: nil, path: "/Applications/Zulu-A.app"),
    ]

    let result = ApplicationRanker.Index(applications: applications).ranked(
      query: "",
      recentLaunches: [:]
    )

    #expect(
      result.map(\.url.path) == [
        "/Applications/Alpha.app",
        "/Applications/Zulu-A.app",
        "/Applications/Zulu-B.app",
      ]
    )
  }

  @Test("Application ranking: launches rank separate installations independently")
  func testIndependentInstallationRecency() {
    let stable = application("Xcode", id: "com.apple.dt.Xcode", path: "/Applications/Xcode.app")
    let beta = application("Xcode", id: "com.apple.dt.Xcode", path: "/Applications/Xcode-Beta.app")
    let index = ApplicationRanker.Index(applications: [stable, beta])

    #expect(stable != beta)
    #expect(
      index.ranked(query: "xcode", recentLaunches: [stable.persistenceKey: Date()]) == [
        stable, beta,
      ]
    )
    #expect(
      index.ranked(query: "xcode", recentLaunches: [beta.persistenceKey: Date()]) == [beta, stable]
    )
  }

  @Test(
    "Application ranking: existing bundle launch history is a fallback for installation history"
  )
  func testLegacyLaunchHistoryFallback() {
    let alpha = application("Alpha", id: "dev.example.Alpha")
    let beta = application("Beta", id: "dev.example.beta")
    let index = ApplicationRanker.Index(applications: [alpha, beta])
    let legacy: [String: Date] = [
      "dev.example.alpha": Date(timeIntervalSince1970: 20),
      beta.persistenceKey: Date(timeIntervalSince1970: 10),
    ]

    #expect(index.ranked(query: "", recentLaunches: legacy) == [alpha, beta])
    var updated = legacy
    updated[alpha.persistenceKey] = Date(timeIntervalSince1970: 5)
    #expect(index.ranked(query: "", recentLaunches: updated) == [beta, alpha])
  }

  @Test("Application identity: symlinks share the identity of their destination")
  func testCanonicalInstallationIdentity() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("Editor.app")
    let alias = directory.appendingPathComponent("Alias.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
    let original = application("Editor", id: "dev.example.editor", path: target.path)
    let linked = application("Editor", id: "dev.example.editor", path: alias.path)

    #expect(original.id == linked.id)
    #expect(original == linked)
    #expect(Set([original, linked]).count == 1)
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

import Foundation
import Testing

@testable import Conjuror

@Suite("Application Catalog")
struct ApplicationCatalogTests {
  @Test("Application catalog: system CoreServices applications directory is included")
  func testIncludesSystemCoreServicesApplicationsDirectory() {
    let directories = ApplicationCatalog.applicationDirectories(mountedVolumeURLs: [])

    #expect(
      directories.contains(
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
      )
    )
  }

  @Test("Application catalog: mounted-volume Applications directories are included")
  func testIncludesApplicationsDirectoryFromMountedVolume() throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let mountedApplications =
      temporaryDirectory
      .appendingPathComponent("Applications", isDirectory: true)
    try fileManager.createDirectory(
      at: mountedApplications,
      withIntermediateDirectories: true
    )

    let directories = ApplicationCatalog.applicationDirectories(
      fileManager: fileManager,
      mountedVolumeURLs: [temporaryDirectory]
    )

    #expect(directories.contains(mountedApplications))
  }

  @Test("Application catalog: helper, background, and Conjuror apps are filtered")
  func testFiltersHelpersBackgroundAppsAndConjuror() {
    let candidates = [
      candidate("Visible", id: "dev.example.visible", path: "/Applications/Visible.app"),
      candidate(
        "Helper",
        id: "dev.example.helper",
        path: "/Applications/Helper.app",
        isHelper: true
      ),
      candidate(
        "Agent",
        id: "dev.example.agent",
        path: "/Applications/Agent.app",
        isBackgroundOnly: true
      ),
      candidate("Conjuror", id: "dev.tombell.conjuror", path: "/Applications/Conjuror.app"),
    ]

    let result = ApplicationCatalog.filteredAndDeduplicated(
      candidates,
      excludingBundleIdentifier: "dev.tombell.conjuror"
    )

    #expect(result.map(\.displayName) == ["Visible"])
  }

  @Test("Application catalog: Conjuror is included when its bundle identifier is not excluded")
  func testIncludesConjurorByDefault() {
    let conjuror = candidate(
      "Conjuror",
      id: "dev.tombell.conjuror",
      path: "/Applications/Conjuror.app"
    )

    let result = ApplicationCatalog.filteredAndDeduplicated(
      [conjuror],
      excludingBundleIdentifier: nil
    )

    #expect(result == [conjuror])
  }

  @Test("Application catalog: distinct installations survive while canonical URLs are deduplicated")
  func testDeduplicatesOnlyByCanonicalURL() {
    let candidates = [
      candidate(
        "Beta Copy",
        id: "dev.example.beta",
        path: "/System/Applications/Beta.app",
        priority: 1
      ),
      candidate("Beta", id: "dev.example.beta", path: "/Applications/Beta.app", priority: 0),
      candidate("Path Copy", id: nil, path: "/Applications/Path.app/../Path.app", priority: 1),
      candidate("Path", id: nil, path: "/Applications/Path.app", priority: 0),
    ]

    let result = ApplicationCatalog.filteredAndDeduplicated(
      candidates,
      excludingBundleIdentifier: nil
    )

    #expect(result.map(\.displayName) == ["Beta", "Path", "Beta Copy"])
  }

  @Test("Application catalog: Xcode releases with the same metadata are separate search results")
  func testSearchesSeparateXcodeInstallations() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    for filename in ["Xcode", "Xcode-27.1.0-Beta"] {
      try createApplication(
        named: filename,
        bundleIdentifier: "com.apple.dt.Xcode",
        packageType: "APPL",
        in: directory,
        displayName: "Xcode"
      )
    }
    let alias = directory.appendingPathComponent("Xcode Alias.app")
    try FileManager.default.createSymbolicLink(
      at: alias,
      withDestinationURL: directory.appendingPathComponent("Xcode.app")
    )

    let candidates = try ApplicationCatalog.scan(directories: [directory])
    let applications = ApplicationCatalog.installedApplications(
      from: ApplicationCatalog.filteredAndDeduplicated(candidates, excludingBundleIdentifier: nil)
    )
    let index = ApplicationRanker.Index(applications: applications)
    let results = index.ranked(query: "xcode", recentLaunches: [:])

    #expect(results.map(\.displayName) == ["Xcode", "Xcode-27.1.0-Beta"])
    #expect(results.map { $0.url.lastPathComponent } == ["Xcode.app", "Xcode-27.1.0-Beta.app"])
    #expect(Set(results.map(\.id)).count == 2)
    #expect(Set(results).count == 2)
    #expect(
      index.ranked(query: "beta", recentLaunches: [:]).map(\.displayName) == ["Xcode-27.1.0-Beta"]
    )
  }

  @Test("Application catalog: identical filenames are distinguished by their directories")
  func testDistinguishesIdenticalFilenames() {
    let applications = ApplicationCatalog.installedApplications(from: [
      candidate("Editor", id: "dev.example.editor", path: "/Applications/Editor.app"),
      candidate("Editor", id: "dev.example.editor", path: "/Volumes/Tools/Applications/Editor.app"),
      candidate("Localized Name", id: "dev.example.other", path: "/Applications/Other.app"),
    ])

    #expect(
      applications.map(\.displayName) == [
        "Editor (/Applications)", "Editor (/Volumes/Tools/Applications)", "Localized Name",
      ]
    )
  }

  @Test("Application catalog: top-level symlinked agent applications are scanned")
  func testScansTopLevelSymlinkedAgentApplications() throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let applicationsDirectory =
      temporaryDirectory
      .appendingPathComponent("Applications", isDirectory: true)
    let appURL =
      temporaryDirectory
      .appendingPathComponent("Safari.app", isDirectory: true)
    let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
    try fileManager.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: contentsURL, withIntermediateDirectories: true)

    let info: [String: Any] = [
      "CFBundleIdentifier": "com.apple.Safari",
      "CFBundleName": "Safari",
      "CFBundlePackageType": "APPL",
      "LSUIElement": true,
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

    #expect(result.map(\.displayName) == ["Safari"])
    #expect(result.first?.bundleIdentifier == "com.apple.Safari")
  }

  @Test("Application catalog: Passwords is scanned despite its XPC package type")
  func testScansPasswordsWithXPCPackageType() throws {
    let fileManager = FileManager.default
    let applicationsDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: applicationsDirectory) }

    try createApplication(
      named: "Passwords",
      bundleIdentifier: "com.apple.Passwords",
      packageType: "XPC!",
      in: applicationsDirectory
    )
    try createApplication(
      named: "Internal Service",
      bundleIdentifier: "com.apple.InternalService",
      packageType: "XPC!",
      in: applicationsDirectory
    )

    let candidates = try ApplicationCatalog.scan(directories: [applicationsDirectory])

    #expect(candidates.map(\.displayName) == ["Passwords"])
    #expect(candidates.first?.bundleIdentifier == "com.apple.Passwords")
  }

  @Test("Application catalog: throws when no configured directory is readable")
  func testThrowsWhenNoConfiguredDirectoryCanBeRead() throws {
    let fileManager = FileManager.default
    let fileURL = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer { try? fileManager.removeItem(at: fileURL) }
    try Data().write(to: fileURL)

    #expect(throws: (any Error).self) { try ApplicationCatalog.scan(directories: [fileURL]) }
  }

  @Test("Application catalog: apps without a package type need an executable")
  func testScansUntypedApplicationsWithExecutables() throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fileManager.removeItem(at: directory) }

    try createApplication(
      named: "Icon Composer",
      bundleIdentifier: "com.apple.IconComposer",
      packageType: nil,
      in: directory,
      executable: true
    )
    try createApplication(
      named: "Incomplete",
      bundleIdentifier: "dev.example.incomplete",
      packageType: nil,
      in: directory
    )
    try createApplication(
      named: "Service",
      bundleIdentifier: "dev.example.service",
      packageType: "XPC!",
      in: directory,
      executable: true
    )

    let candidates = try ApplicationCatalog.scan(directories: [directory])

    #expect(candidates.map(\.displayName) == ["Icon Composer"])
  }

  @Test("Application catalog: returns empty when at least one configured directory is readable")
  func testReturnsEmptyWhenAtLeastOneConfiguredDirectoryIsReadable() throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let readableDirectory =
      temporaryDirectory
      .appendingPathComponent("Readable", isDirectory: true)
    let unreadableFile = temporaryDirectory.appendingPathComponent("Not-A-Directory")
    try fileManager.createDirectory(
      at: readableDirectory,
      withIntermediateDirectories: true
    )
    try Data().write(to: unreadableFile)

    let candidates = try ApplicationCatalog.scan(
      directories: [unreadableFile, readableDirectory]
    )

    #expect(candidates.isEmpty)
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

  private func createApplication(
    named name: String,
    bundleIdentifier: String,
    packageType: String?,
    in directory: URL,
    executable: Bool = false,
    displayName: String? = nil
  ) throws {
    let contentsURL =
      directory
      .appendingPathComponent("\(name).app", isDirectory: true)
      .appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

    var info: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleName": name,
    ]
    info["CFBundlePackageType"] = packageType
    info["CFBundleDisplayName"] = displayName
    if executable {
      info["CFBundleExecutable"] = name
      let executableDirectory = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
      try FileManager.default.createDirectory(
        at: executableDirectory,
        withIntermediateDirectories: true
      )
      let executableURL = executableDirectory.appendingPathComponent(name)
      try Data("#!/bin/sh\n".utf8).write(to: executableURL)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: executableURL.path
      )
    }
    let infoData = try PropertyListSerialization.data(
      fromPropertyList: info,
      format: .xml,
      options: 0
    )
    try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))
  }
}

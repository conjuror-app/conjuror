import Foundation
import Testing

@testable import Conjuror

@Suite("Running Application Catalog")
struct RunningApplicationCatalogTests {
  @Test("Lists regular apps other than Conjuror and excluded installations, with catalog names")
  func testFiltersAndNamesRunningApplications() {
    let stable = URL(fileURLWithPath: "/Applications/Xcode.app")
    let beta = URL(fileURLWithPath: "/Applications/Xcode-beta.app")
    let installed = [
      InstalledApplication(
        displayName: "Xcode",
        bundleIdentifier: "com.apple.dt.Xcode",
        url: stable
      ),
      InstalledApplication(
        displayName: "Xcode-beta",
        bundleIdentifier: "com.apple.dt.Xcode",
        url: beta
      ),
    ]
    let candidates = [
      candidate(1, "Xcode", url: stable),
      candidate(2, "Xcode", url: beta),
      candidate(3, "Conjuror", url: URL(fileURLWithPath: "/Applications/Conjuror.app")),
      candidate(4, "Menu Bar Tool", isRegular: false),
      candidate(5, "Gone", isTerminated: true),
      candidate(6, "Excluded", url: URL(fileURLWithPath: "/Applications/Excluded.app")),
      candidate(7, "Notes", url: URL(fileURLWithPath: "/System/Applications/Notes.app")),
      candidate(8, nil, url: nil),
    ]

    let applications = RunningApplicationCatalog.applications(
      from: candidates,
      ownProcessIdentifier: 3,
      installed: installed,
      excludedPaths: [URL(fileURLWithPath: "/Applications/Excluded.app").canonicalFileURL.path]
    )

    #expect(applications.map(\.processIdentifier) == [1, 2, 7, 8])
    #expect(applications.map(\.displayName) == ["Xcode", "Xcode-beta", "Notes", "Process 8"])
  }

  private func candidate(
    _ processIdentifier: pid_t,
    _ name: String?,
    url: URL? = nil,
    isRegular: Bool = true,
    isTerminated: Bool = false
  ) -> RunningApplicationCandidate {
    RunningApplicationCandidate(
      processIdentifier: processIdentifier,
      localizedName: name,
      bundleIdentifier: nil,
      bundleURL: url,
      isRegular: isRegular,
      isHidden: false,
      isTerminated: isTerminated
    )
  }
}

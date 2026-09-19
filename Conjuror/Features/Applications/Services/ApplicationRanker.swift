import Foundation

struct ApplicationRanker {
  struct Index {
    private let index: SearchIndex<InstalledApplication>
    private let legacyRecencyKeys: [String: String]

    init(applications: [InstalledApplication]) {
      legacyRecencyKeys = applications.reduce(into: [:]) { keys, application in
        guard !application.isSystemSettingsItem,
          let bundleIdentifier = application.bundleIdentifier
        else { return }
        keys[application.persistenceKey] = bundleIdentifier.lowercased()
      }
      index = SearchIndex(
        candidates: applications.map { application in
          SearchIndex.Candidate(
            item: application,
            name: application.displayName,
            secondaryText: application.bundleIdentifier ?? "",
            recencyKey: application.persistenceKey,
            stableKey: application.url.path
          )
        }
      )
    }

    func ranked(
      query: String,
      recentLaunches: [String: Date]
    ) -> [InstalledApplication] {
      // Keep existing launch history until each installation has its own recorded launch.
      var recency = recentLaunches
      for (key, legacyKey) in legacyRecencyKeys where recency[key] == nil {
        recency[key] = recentLaunches[legacyKey]
      }
      return index.ranked(query: query, recency: recency)
    }
  }
}

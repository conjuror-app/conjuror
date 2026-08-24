import Foundation

struct ApplicationRanker {
  struct Index {
    private let index: SearchIndex<InstalledApplication>

    init(applications: [InstalledApplication]) {
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
      index.ranked(query: query, recency: recentLaunches)
    }
  }
}

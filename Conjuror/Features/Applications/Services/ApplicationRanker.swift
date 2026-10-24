import Foundation

extension SearchIndex where Item == InstalledApplication {
  init(applications: [InstalledApplication]) {
    self.init(
      candidates: applications.map { application in
        Candidate(
          item: application,
          name: application.displayName,
          secondaryText: application.bundleIdentifier ?? "",
          recencyKey: application.persistenceKey,
          // Keep existing launch history until each installation has its own recorded launch.
          fallbackRecencyKey: application.isSystemSettingsItem
            ? nil : application.bundleIdentifier?.lowercased(),
          stableKey: application.url.path
        )
      }
    )
  }
}

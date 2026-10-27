import Foundation

extension InstalledApplication: SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: displayName,
      secondaryText: bundleIdentifier ?? "",
      recencyKey: persistenceKey,
      // Keep existing launch history until each installation has its own recorded launch.
      fallbackRecencyKey: isSystemSettingsItem ? nil : bundleIdentifier?.lowercased(),
      stableKey: url.path
    )
  }
}

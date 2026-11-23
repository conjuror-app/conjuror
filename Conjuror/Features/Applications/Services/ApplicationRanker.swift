import Foundation

extension InstalledApplication: SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: displayName,
      secondaryText: bundleIdentifier ?? "",
      recencyKey: persistenceKey,
      fallbackRecencyKey: isSystemSettingsItem ? nil : bundleIdentifier?.lowercased(),
      stableKey: url.path
    )
  }
}

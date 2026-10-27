import Foundation

extension AppleShortcut: SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: name,
      secondaryText: subtitle,
      recencyKey: persistenceKey,
      stableKey: id
    )
  }
}

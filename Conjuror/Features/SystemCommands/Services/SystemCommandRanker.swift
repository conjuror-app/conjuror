import Foundation

extension SystemCommand: SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: title,
      secondaryText: keywords,
      recencyKey: persistenceKey,
      stableKey: id
    )
  }
}

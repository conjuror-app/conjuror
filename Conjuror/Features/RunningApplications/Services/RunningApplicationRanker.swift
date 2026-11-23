import Foundation

extension RunningApplication: SearchIndexable {
  var searchCandidate: SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: self,
      name: displayName,
      secondaryText: bundleIdentifier ?? "",
      recencyKey: "",
      stableKey: String(processIdentifier)
    )
  }
}

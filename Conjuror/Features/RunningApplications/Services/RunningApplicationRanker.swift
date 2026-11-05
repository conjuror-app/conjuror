import Foundation

extension RunningApplication: SearchIndexable {
  /// Running apps have no recorded uses, so an empty query lists them by name, like the Force
  /// Quit window.
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

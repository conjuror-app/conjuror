/// An item ranked in application search: an app, a System Settings section, or a system command.
enum ApplicationSearchResult: Identifiable {
  case application(InstalledApplication)
  case systemCommand(SystemCommand)

  var id: LauncherResultID {
    switch self {
    case .application(let application): .application(application.id)
    case .systemCommand(let command): .systemCommand(command.id)
    }
  }

  var application: InstalledApplication? {
    if case .application(let application) = self { application } else { nil }
  }
}

extension ApplicationSearchResult: SearchIndexable {
  private static func wrapping<Item>(
    _ candidate: SearchIndex<Item>.Candidate,
    as item: Self
  ) -> SearchIndex<Self>.Candidate {
    SearchIndex.Candidate(
      item: item,
      name: candidate.name,
      secondaryText: candidate.secondaryText,
      recencyKey: candidate.recencyKey,
      fallbackRecencyKey: candidate.fallbackRecencyKey,
      stableKey: candidate.stableKey
    )
  }

  var searchCandidate: SearchIndex<Self>.Candidate {
    switch self {
    case .application(let application):
      Self.wrapping(application.searchCandidate, as: self)
    case .systemCommand(let command):
      Self.wrapping(command.searchCandidate, as: self)
    }
  }
}

import Foundation

extension SearchIndex where Item == AppleShortcut {
  init(shortcuts: [AppleShortcut]) {
    self.init(
      candidates: shortcuts.map { shortcut in
        Candidate(
          item: shortcut,
          name: shortcut.name,
          secondaryText: shortcut.subtitle,
          recencyKey: shortcut.persistenceKey,
          stableKey: shortcut.id
        )
      }
    )
  }
}

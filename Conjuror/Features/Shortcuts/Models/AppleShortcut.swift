import Foundation

struct AppleShortcut: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let subtitle: String
  let acceptsInput: Bool

  var persistenceKey: String {
    "shortcut:\(id.lowercased())"
  }
}

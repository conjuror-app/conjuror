import Foundation

struct AppleShortcut: Codable, Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let subtitle: String
  let acceptsInput: Bool
  let iconData: Data?

  var persistenceKey: String {
    "shortcut:\(id.lowercased())"
  }

  init(
    id: String,
    name: String,
    subtitle: String,
    acceptsInput: Bool,
    iconData: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.subtitle = subtitle
    self.acceptsInput = acceptsInput
    self.iconData = iconData
  }
}

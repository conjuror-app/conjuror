import Foundation

struct AppleShortcut: Identifiable, Hashable, Sendable {
  struct Color: Hashable, Sendable {
    let red: UInt16
    let green: UInt16
    let blue: UInt16
  }

  let id: String
  let name: String
  let subtitle: String
  let acceptsInput: Bool
  let color: Color?
  let iconData: Data?

  var persistenceKey: String {
    "shortcut:\(id.lowercased())"
  }

  init(
    id: String,
    name: String,
    subtitle: String,
    acceptsInput: Bool,
    color: Color? = nil,
    iconData: Data? = nil
  ) {
    self.id = id
    self.name = name
    self.subtitle = subtitle
    self.acceptsInput = acceptsInput
    self.color = color
    self.iconData = iconData
  }
}

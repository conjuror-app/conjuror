import Foundation

struct ApplicationCustomization: Codable, Equatable {
  static func validationError(
    forAlias alias: String,
    path: String,
    among customizations: [String: ApplicationCustomization]
  ) -> String? {
    if alias.contains(where: \.isWhitespace) { return "Aliases can’t contain spaces." }

    if let prefix = alias.first, LauncherMode.requested(byPrefix: prefix) != nil {
      return "Aliases can’t start with ;, >, :, /, ! or @."
    }

    let normalizedAlias = SearchText.normalized(alias)

    if let other = customizations.first(where: {
      $0.key != path && $0.value.alias.map(SearchText.normalized) == normalizedAlias
    })?.value {
      return "“\(alias)” is already the alias for \(other.name)."
    }

    return nil
  }

  var name: String
  var bundleIdentifier: String?
  var alias: String?
  var hotKey: HotKeyConfiguration?

  var isEmpty: Bool {
    alias == nil && hotKey == nil
  }
}

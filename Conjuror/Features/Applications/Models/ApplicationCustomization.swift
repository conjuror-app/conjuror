import Foundation

/// An alias and hot key for one app installation, stored by its persistence key.
struct ApplicationCustomization: Codable, Equatable {
  /// Returns why `alias` can't be used by the app at `path`, or `nil` if it can.
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

  /// Shown in Settings when the app is no longer installed.
  var name: String
  /// Finds the app again after it moves.
  var bundleIdentifier: String?
  var alias: String?
  var hotKey: HotKeyConfiguration?

  var isEmpty: Bool {
    alias == nil && hotKey == nil
  }
}

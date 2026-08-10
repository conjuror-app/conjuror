import AppKit
import Foundation

struct InstalledApplication: Identifiable {
  let displayName: String
  let bundleIdentifier: String?
  let url: URL
  let icon: NSImage

  var id: String {
    persistenceKey
  }

  var persistenceKey: String {
    bundleIdentifier?.lowercased() ?? url.standardizedFileURL.resolvingSymlinksInPath().path
  }
}

extension InstalledApplication: Equatable {
  static func == (lhs: InstalledApplication, rhs: InstalledApplication) -> Bool {
    lhs.persistenceKey == rhs.persistenceKey
  }
}

extension InstalledApplication: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(persistenceKey)
  }
}

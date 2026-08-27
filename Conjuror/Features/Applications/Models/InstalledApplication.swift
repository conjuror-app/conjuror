import AppKit
import Foundation

struct InstalledApplication: Identifiable {
  enum LaunchTarget: Equatable {
    case application
    case systemSettings(URL)
  }

  let displayName: String
  let bundleIdentifier: String?
  let url: URL
  let launchTarget: LaunchTarget

  @MainActor
  var icon: NSImage {
    iconOverride ?? ApplicationIconCache.shared.icon(for: url)
  }

  private let iconOverride: NSImage?

  var id: String {
    persistenceKey
  }

  var persistenceKey: String {
    switch launchTarget {
    case .application:
      bundleIdentifier?.lowercased() ?? url.standardizedFileURL.resolvingSymlinksInPath().path
    case .systemSettings(let url):
      url.absoluteString.lowercased()
    }
  }

  var isSystemSettingsItem: Bool {
    if case .systemSettings = launchTarget { true } else { false }
  }

  init(
    displayName: String,
    bundleIdentifier: String?,
    url: URL,
    icon: NSImage? = nil,
    launchTarget: LaunchTarget = .application
  ) {
    self.displayName = displayName
    self.bundleIdentifier = bundleIdentifier
    self.url = url
    self.launchTarget = launchTarget
    iconOverride = icon
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

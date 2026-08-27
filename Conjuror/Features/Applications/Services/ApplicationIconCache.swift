import AppKit

@MainActor
final class ApplicationIconCache {
  static let shared = ApplicationIconCache()

  private let cache = NSCache<NSString, NSImage>()

  private init() {
    cache.countLimit = 32
  }

  func icon(for url: URL) -> NSImage {
    let key = url.standardizedFileURL.path as NSString
    if let icon = cache.object(forKey: key) {
      return icon
    }

    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 32, height: 32)
    cache.setObject(icon, forKey: key)
    return icon
  }
}

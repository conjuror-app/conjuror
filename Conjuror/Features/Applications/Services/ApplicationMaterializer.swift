import AppKit
import Foundation

@MainActor
struct ApplicationMaterializer: ApplicationMaterializing {
  func materialize(_ candidates: [ApplicationCatalogCandidate]) -> [InstalledApplication] {
    candidates.map { candidate in
      let icon = NSWorkspace.shared.icon(forFile: candidate.url.path)
      icon.size = NSSize(width: 32, height: 32)
      return InstalledApplication(
        displayName: candidate.displayName,
        bundleIdentifier: candidate.bundleIdentifier,
        url: candidate.url,
        icon: icon
      )
    }
  }
}

@MainActor
protocol ApplicationMaterializing {
  func materialize(_ candidates: [ApplicationCatalogCandidate]) -> [InstalledApplication]
}

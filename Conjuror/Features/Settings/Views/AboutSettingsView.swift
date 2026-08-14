import AppKit
import SwiftUI

struct AboutSettingsView: View {
  private static let githubURL = URL(string: "https://github.com/tombell/conjuror")!
  private static let licenseURL = URL(
    string: "https://github.com/tombell/conjuror/blob/main/LICENSE"
  )!

  var body: some View {
    VStack(spacing: 12) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .interpolation(.high)
        .frame(width: 72, height: 72)

      Text("Conjuror")
        .font(.title2.weight(.semibold))

      Text(versionDescription)
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 16) {
        Link("GitHub", destination: Self.githubURL)
        Link("License", destination: Self.licenseURL)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }

  private var versionDescription: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Unknown"
    let build =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ?? "Unknown"
    return "Version \(version) (\(build))"
  }
}

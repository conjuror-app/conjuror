import SwiftUI

/// Caption text under a setting: an explanation, a warning, or an error.
struct SettingsNote: View {
  enum Style {
    case info
    case warning
    case error
  }

  let text: String
  var style = Style.info

  var body: some View {
    Group {
      switch style {
      case .info:
        Text(text)
          .foregroundStyle(.secondary)
      case .warning:
        Label(text, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
      case .error:
        Label(text, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
    }
    .font(.caption)
    .fixedSize(horizontal: false, vertical: true)
  }
}

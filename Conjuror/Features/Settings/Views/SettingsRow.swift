import SwiftUI

struct SettingsRow<Content: View>: View {
  let title: String
  let description: String
  @ViewBuilder let content: Content

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 24)
      content
    }
  }
}

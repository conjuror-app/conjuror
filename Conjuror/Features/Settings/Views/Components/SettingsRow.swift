import SwiftUI

/// A titled setting with its control, and optional notes underneath that belong to it.
struct SettingsRow<Content: View, Footer: View>: View {
  let title: String
  let description: String
  @ViewBuilder let content: Content
  @ViewBuilder let footer: Footer

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 24)
        content
      }

      footer
    }
  }
}

extension SettingsRow where Footer == EmptyView {
  init(title: String, description: String, @ViewBuilder content: () -> Content) {
    self.init(title: title, description: description, content: content) {
      EmptyView()
    }
  }
}

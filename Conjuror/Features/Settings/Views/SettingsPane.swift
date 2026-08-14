import SwiftUI

struct SettingsPane<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      content
    }
    .padding(24)
  }
}

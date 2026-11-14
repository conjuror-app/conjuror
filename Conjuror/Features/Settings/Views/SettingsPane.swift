import SwiftUI

/// Lays out a settings pane's groups. A pane that holds a list stretching with the window
/// turns scrolling off so the list scrolls instead.
struct SettingsPane<Content: View>: View {
  var scrolls = true
  @ViewBuilder let content: Content

  var body: some View {
    if scrolls {
      ScrollView {
        groups
      }
    } else {
      groups
        .frame(maxHeight: .infinity, alignment: .top)
    }
  }

  private var groups: some View {
    VStack(alignment: .leading, spacing: 20) {
      content
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .toggleStyle(.switch)
  }
}

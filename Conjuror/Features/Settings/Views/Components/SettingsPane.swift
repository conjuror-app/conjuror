import SwiftUI

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
    .padding([.horizontal, .bottom], 24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .toggleStyle(.switch)
  }
}

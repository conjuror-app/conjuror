import SwiftUI

/// A headed, scrolling card of rows with an Add button.
struct SettingsListCard<Content: View>: View {
  let title: String
  let description: String
  let emptyText: String
  let isEmpty: Bool
  let onAdd: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        Button("Add…", action: onAdd)
      }
      .padding(.leading, SettingsCardMetrics.horizontalPadding)

      Text(description)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, SettingsCardMetrics.horizontalPadding)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if isEmpty {
            Text(emptyText)
              .foregroundStyle(.secondary)
              .padding(.horizontal, SettingsCardMetrics.horizontalPadding)
              .padding(.vertical, SettingsCardMetrics.verticalPadding)
          }

          SettingsDividedRows {
            content
          }
        }
      }
      .settingsCard()
    }
  }
}

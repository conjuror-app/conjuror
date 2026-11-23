import SwiftUI

struct SettingsGroup<Content: View>: View {
  var title: String?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        Text(title)
          .font(.headline)
          .padding(.leading, SettingsCardMetrics.horizontalPadding)
      }

      VStack(alignment: .leading, spacing: 0) {
        SettingsDividedRows {
          content
        }
      }
      .settingsCard()
    }
  }
}

struct SettingsDividedRows<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    Group(subviews: content) { subviews in
      ForEach(subviews) { subview in
        if subview.id != subviews.first?.id {
          Divider()
            .padding(.leading, SettingsCardMetrics.horizontalPadding)
        }

        subview
          .padding(.horizontal, SettingsCardMetrics.horizontalPadding)
          .padding(.vertical, SettingsCardMetrics.verticalPadding)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

enum SettingsCardMetrics {
  static let horizontalPadding: CGFloat = 12
  static let verticalPadding: CGFloat = 10
  static let headerIconSize: CGFloat = 40
}

extension View {
  func settingsCard() -> some View {
    background(.quaternary.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

import SwiftUI

/// The card heading a module's pane: its icon, name, current status, and the switch that
/// turns it on, with optional notes underneath.
struct SettingsHeroCard<Footer: View>: View {
  let section: SettingsSection
  let title: String
  let status: String
  @Binding var isOn: Bool
  @ViewBuilder let footer: Footer

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        SettingsIconTile(section: section, size: 40)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
          Text(status)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 24)
        Toggle(title, isOn: $isOn)
          .labelsHidden()
      }

      footer
    }
    .padding(SettingsCardMetrics.horizontalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .settingsCard()
  }
}

extension SettingsHeroCard where Footer == EmptyView {
  init(section: SettingsSection, title: String, status: String, isOn: Binding<Bool>) {
    self.init(section: section, title: title, status: status, isOn: isOn) {
      EmptyView()
    }
  }
}

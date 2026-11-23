import SwiftUI

struct SettingsHeroCard<Footer: View>: View {
  let section: SettingsSection
  let title: String
  let status: String
  @Binding var isOn: Bool
  @ViewBuilder let footer: Footer

  var body: some View {
    SettingsHeaderCard(title: title, subtitle: status) {
      SettingsIconTile(section: section, size: SettingsCardMetrics.headerIconSize)
    } accessory: {
      Toggle(title, isOn: $isOn)
        .labelsHidden()
    } footer: {
      footer
    }
  }
}

extension SettingsHeroCard where Footer == EmptyView {
  init(section: SettingsSection, title: String, status: String, isOn: Binding<Bool>) {
    self.init(section: section, title: title, status: status, isOn: isOn) {
      EmptyView()
    }
  }
}

struct SettingsHeaderCard<Icon: View, Accessory: View, Footer: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder let icon: Icon
  @ViewBuilder let accessory: Accessory
  @ViewBuilder let footer: Footer

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        icon
          .frame(
            width: SettingsCardMetrics.headerIconSize,
            height: SettingsCardMetrics.headerIconSize
          )

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 24)
        accessory
      }

      footer
    }
    .padding(SettingsCardMetrics.horizontalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .settingsCard()
  }
}

extension SettingsHeaderCard where Accessory == EmptyView, Footer == EmptyView {
  init(title: String, subtitle: String, @ViewBuilder icon: () -> Icon) {
    self.init(title: title, subtitle: subtitle, icon: icon) {
      EmptyView()
    } footer: {
      EmptyView()
    }
  }
}

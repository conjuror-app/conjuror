import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(SettingsSection.allCases) { section in
          sidebarButton(for: section)
        }
        Spacer()
      }
      .padding(12)
      .frame(width: 164)
      .background(.thinMaterial)

      Divider()

      VStack(alignment: .leading, spacing: 0) {
        Text(selection.title)
          .font(.title2.weight(.semibold))
          .padding(.horizontal, 24)
          .padding(.top, 20)
          .padding(.bottom, 12)

        Divider()

        detail(for: selection)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(width: 640, height: 420)
    .onAppear {
      launchAtLoginStore.refresh()
    }
  }

  @State private var selection = SettingsSection.general

  private func sidebarButton(for section: SettingsSection) -> some View {
    Button {
      selection = section
    } label: {
      Label(section.title, systemImage: section.systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      selection == section ? Color.accentColor.opacity(0.18) : .clear,
      in: RoundedRectangle(cornerRadius: 7)
    )
  }

  @ViewBuilder
  private func detail(for section: SettingsSection) -> some View {
    switch section {
    case .general:
      GeneralSettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        launchAtLoginStore: launchAtLoginStore
      )
    case .emoji:
      EmojiSettingsView(store: store)
    case .calculator:
      CalculatorSettingsView(currencyRateStore: currencyRateStore)
    case .about:
      AboutSettingsView()
    }
  }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case emoji
  case calculator
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .emoji: "Emoji"
    case .calculator: "Calculator"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .emoji: "face.smiling"
    case .calculator: "function"
    case .about: "info.circle"
    }
  }
}

import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    TabView {
      GeneralSettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        launchAtLoginStore: launchAtLoginStore
      )
      .tabItem {
        Label("General", systemImage: "gearshape")
      }

      EmojiSettingsView(store: store)
        .tabItem {
          Label("Emoji", systemImage: "face.smiling")
        }

      CalculatorSettingsView(currencyRateStore: currencyRateStore)
        .tabItem {
          Label("Calculator", systemImage: "function")
        }

      AboutSettingsView()
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
    }
    .frame(width: 520, height: 400)
    .onAppear {
      launchAtLoginStore.refresh()
    }
  }
}

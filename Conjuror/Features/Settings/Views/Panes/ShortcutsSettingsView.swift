import SwiftUI

struct ShortcutsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsHeroCard(
        section: .shortcuts,
        title: "Apple Shortcuts",
        status: store.isShortcutsModeEnabled
          ? "Searching and running your Apple Shortcuts."
          : "Off. Turn on to run Apple Shortcuts from the launcher.",
        isOn: Binding(
          get: { store.isShortcutsModeEnabled },
          set: { isEnabled in
            store.setShortcutsModeEnabled(isEnabled)
            hotKeyStore.register()
          }
        )
      )

      if store.isShortcutsModeEnabled {
        SettingsGroup(title: "Launcher") {
          ModeShortcutSettingsRow(
            description: "Open the launcher directly in Apple Shortcuts mode.",
            action: .shortcuts,
            store: store,
            hotKeyStore: hotKeyStore
          )
        }
      }
    }
  }
}

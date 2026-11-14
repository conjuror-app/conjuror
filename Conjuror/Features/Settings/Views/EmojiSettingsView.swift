import SwiftUI

struct EmojiSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsHeroCard(
        section: .emoji,
        title: "Emoji",
        status: store.isEmojiModeEnabled
          ? "Searching emoji by name, gender, or skin tone."
          : "Off. Turn on to search emoji from the launcher.",
        isOn: Binding(
          get: { store.isEmojiModeEnabled },
          set: { isEnabled in
            store.setEmojiModeEnabled(isEnabled)
            hotKeyStore.register()
          }
        )
      )

      if store.isEmojiModeEnabled {
        SettingsGroup {
          ModeShortcutSettingsRow(
            description: "Open the launcher directly in emoji mode.",
            action: .emoji,
            store: store,
            hotKeyStore: hotKeyStore
          )

          SettingsRow(
            title: "Preferred skin tone",
            description: "Automatically apply this tone to emoji that support it."
          ) {
            Picker(
              "Emoji skin tone",
              selection: Binding(
                get: { store.preferredEmojiSkinTone },
                set: { skinTone in
                  store.setPreferredEmojiSkinTone(skinTone)
                }
              )
            ) {
              ForEach(EmojiSkinTone.allCases) { skinTone in
                Text("\(skinTone.exampleEmoji)  \(skinTone.displayName)").tag(skinTone)
              }
            }
            .labelsHidden()
            .frame(width: 170)
          }
        }
      }
    }
  }
}

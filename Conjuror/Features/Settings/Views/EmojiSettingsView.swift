import SwiftUI

struct EmojiSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
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

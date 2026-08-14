import SwiftUI

struct EmojiSettingsView: View {
  @ObservedObject var store: SettingsStore

  var body: some View {
    SettingsPane {
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

      Spacer()
    }
  }
}

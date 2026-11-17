import SwiftUI

struct FilesSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsHeroCard(
        section: .files,
        title: "Files",
        status: store.isFilesModuleEnabled
          ? "Searching Spotlight-indexed files and folders."
          : "Off. Turn on to search files and folders from the launcher.",
        isOn: Binding(
          get: { store.isFilesModuleEnabled },
          set: { isEnabled in
            store.setFilesModuleEnabled(isEnabled)
            hotKeyStore.register()
          }
        )
      )

      if store.isFilesModuleEnabled {
        SettingsGroup(title: "Launcher") {
          ModeShortcutSettingsRow(
            description: "Open the launcher directly in files mode.",
            action: .files,
            store: store,
            hotKeyStore: hotKeyStore
          )
        }

        SettingsGroup(title: "Folder access") {
          SettingsRow(
            title: "Protected folders",
            description:
              "Allow Conjuror to find files in Desktop, Documents, Downloads, and iCloud Drive."
          ) {
            Button("Grant Access") {
              FileAccessAuthorizer.requestAccess()
            }
          } footer: {
            SettingsNote(
              text:
                "macOS controls access to protected folders. Approve each prompt to include that folder in file search results."
            )
          }
        }
      }
    }
  }
}

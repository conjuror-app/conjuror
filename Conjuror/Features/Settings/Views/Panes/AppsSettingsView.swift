import SwiftUI

struct AppsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane(scrolls: false) {
      SettingsGroup(title: "Launcher") {
        SettingsRow(
          title: "Keyboard shortcut",
          description: "Show or hide the apps launcher from anywhere."
        ) {
          ShortcutRecorder(
            configuration: store.hotKeyConfiguration,
            onChange: { configuration in
              hotKeyErrorMessage = hotKeyStore.updateConfiguration(configuration, for: .launcher)
              return hotKeyErrorMessage == nil
            },
            onRecordingChange: hotKeyStore.setShortcutRecording
          )
          .frame(width: 120, height: 28)
        } footer: {
          if let hotKeyErrorMessage {
            SettingsNote(text: hotKeyErrorMessage, style: .error)
          }
        }

        SettingsRow(
          title: "System Settings results",
          description: "Include System Settings sections in apps search."
        ) {
          Toggle(
            "System Settings results",
            isOn: Binding(
              get: { store.showsSystemSettingsItems },
              set: { store.setShowsSystemSettingsItems($0) }
            )
          )
          .labelsHidden()
        }

        SettingsRow(
          title: "System commands",
          description: "Include lock, sleep, restart, and other system commands in apps search."
        ) {
          Toggle(
            "System commands",
            isOn: Binding(
              get: { store.showsSystemCommands },
              set: { store.setShowsSystemCommands($0) }
            )
          )
          .labelsHidden()
        }
      }

      Picker("App list", selection: $appList) {
        ForEach(AppList.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: .infinity)

      Group {
        switch appList {
        case .customizations:
          ApplicationCustomizationsView(
            store: store,
            launcherStore: launcherStore,
            hotKeyStore: hotKeyStore
          )
        case .excluded:
          ExcludedApplicationsView(store: store, launcherStore: launcherStore)
        }
      }
      .frame(maxHeight: .infinity)

      HStack {
        Spacer()
        Button("Reset to Defaults") {
          store.resetToDefaults()
          hotKeyStore.register()
          hotKeyErrorMessage = hotKeyStore.registrationErrorMessage
        }
        .buttonStyle(SettingsDestructiveButtonStyle())
      }
    }
  }

  @State private var hotKeyErrorMessage: String?
  @State private var appList = AppList.customizations
}

private enum AppList: CaseIterable, Identifiable {
  case customizations
  case excluded

  var id: Self { self }

  var title: String {
    switch self {
    case .customizations: "Aliases & Hotkeys"
    case .excluded: "Excluded"
    }
  }
}

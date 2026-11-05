import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
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
        launchAtLoginStore: launchAtLoginStore
      )
    case .apps:
      AppsSettingsView(store: store, launcherStore: launcherStore, hotKeyStore: hotKeyStore)
    case .emoji:
      EmojiSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .shortcuts:
      ShortcutsSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .calculator:
      CalculatorSettingsView(currencyRateStore: currencyRateStore)
    case .files:
      FilesSettingsView(
        store: store,
        hotKeyStore: hotKeyStore
      )
    case .quicklinks:
      QuicklinksSettingsView(store: store)
    case .about:
      AboutSettingsView()
    }
  }
}

struct ModeShortcutSettingsRow: View {
  let description: String
  let action: HotKeyAction
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    Group {
      SettingsRow(title: "Keyboard shortcut", description: description) {
        HStack {
          Toggle(
            "Keyboard shortcut",
            isOn: Binding(
              get: { configuration != nil },
              set: { isEnabled in
                errorMessage = hotKeyStore.updateConfiguration(
                  isEnabled ? action.defaultConfiguration : nil,
                  for: action
                )
              }
            )
          )
          .labelsHidden()

          if let configuration {
            ShortcutRecorder(
              configuration: configuration,
              onChange: { newConfiguration in
                errorMessage = hotKeyStore.updateConfiguration(newConfiguration, for: action)
                return errorMessage == nil
              },
              onRecordingChange: hotKeyStore.setShortcutRecording
            )
            .frame(width: 120, height: 28)
          }
        }
      }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }
    }
  }

  private var configuration: HotKeyConfiguration? {
    store.hotKeyConfiguration(for: action)
  }

  @State private var errorMessage: String?
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case apps
  case emoji
  case shortcuts
  case calculator
  case files
  case quicklinks
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .apps: "Apps"
    case .emoji: "Emoji"
    case .shortcuts: "Shortcuts"
    case .calculator: "Calculator"
    case .files: "Files"
    case .quicklinks: "Quicklinks"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .apps: "square.grid.2x2"
    case .emoji: "face.smiling"
    case .shortcuts: "square.stack.3d.up"
    case .calculator: "function"
    case .files: "folder"
    case .quicklinks: "link"
    case .about: "info.circle"
    }
  }
}

private struct AppsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
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

      if let hotKeyErrorMessage {
        Label(hotKeyErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }

      ExcludedApplicationsView(store: store, launcherStore: launcherStore)
        .frame(maxHeight: .infinity)

      HStack {
        Spacer()
        Button("Reset to Defaults") {
          store.resetToDefaults()
          hotKeyStore.register()
          hotKeyErrorMessage = hotKeyStore.registrationErrorMessage
        }
      }
    }
  }

  @State private var hotKeyErrorMessage: String?
}

private struct ShortcutsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      ModeShortcutSettingsRow(
        description: "Open the launcher directly in Apple Shortcuts mode.",
        action: .shortcuts,
        store: store,
        hotKeyStore: hotKeyStore
      )

      Spacer()
    }
  }
}

private struct FilesSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Files module",
        description: "Search Spotlight-indexed files and folders from the launcher."
      ) {
        Toggle(
          "Files module",
          isOn: Binding(
            get: { store.isFilesModuleEnabled },
            set: { isEnabled in
              store.setFilesModuleEnabled(isEnabled)
            }
          )
        )
        .labelsHidden()
      }

      if store.isFilesModuleEnabled {
        ModeShortcutSettingsRow(
          description: "Open the launcher directly in files mode.",
          action: .files,
          store: store,
          hotKeyStore: hotKeyStore
        )

        SettingsRow(
          title: "Protected folders",
          description:
            "Allow Conjuror to find files in Desktop, Documents, Downloads, and iCloud Drive."
        ) {
          Button("Grant Access") {
            FileAccessAuthorizer.requestAccess()
          }
        }

        Text(
          "macOS controls access to protected folders. Approve each prompt to include that folder in file search results."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer()
    }
  }
}

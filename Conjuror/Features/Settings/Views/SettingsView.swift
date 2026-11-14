import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore

  var body: some View {
    // The window's content runs under its title bar, whose height is the top safe area.
    GeometryReader { proxy in
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(SettingsSection.groups, id: \.self) { group in
            VStack(alignment: .leading, spacing: 2) {
              ForEach(group) { section in
                sidebarButton(for: section)
              }
            }
          }
          Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 164)
        .background(.thinMaterial)
        .overlay(alignment: .trailing) {
          Divider()
            .ignoresSafeArea()
        }

        VStack(alignment: .leading, spacing: 0) {
          Text(selection.title)
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 24)
            .frame(height: proxy.safeAreaInsets.top)

          detail(for: selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
      }
    }
    .frame(width: 640)
    .frame(maxHeight: .infinity)
    .onAppear {
      launchAtLoginStore.refresh()
    }
  }

  @State private var selection = SettingsSection.general

  private func sidebarButton(for section: SettingsSection) -> some View {
    Button {
      selection = section
    } label: {
      HStack(spacing: 8) {
        Image(systemName: section.systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(
            section.tint.gradient,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
          )

        Text(section.title)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .frame(height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      selection == section ? Color.primary.opacity(0.1) : .clear,
      in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .accessibilityAddTraits(selection == section ? .isSelected : [])
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
    case .clipboard:
      ClipboardSettingsView(store: store, launcherStore: launcherStore, hotKeyStore: hotKeyStore)
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
    } footer: {
      if let errorMessage {
        SettingsNote(text: errorMessage, style: .error)
      }
    }
  }

  private var configuration: HotKeyConfiguration? {
    store.hotKeyConfiguration(for: action)
  }

  @State private var errorMessage: String?
}

private enum SettingsSection: String, Identifiable {
  /// Sidebar order, with a gap between groups.
  static let groups: [[SettingsSection]] = [
    [.general],
    [.apps, .emoji, .clipboard, .shortcuts, .calculator, .files, .quicklinks],
    [.about],
  ]

  case general
  case apps
  case emoji
  case clipboard
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
    case .clipboard: "Clipboard"
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
    case .clipboard: "doc.on.clipboard"
    case .shortcuts: "square.stack.3d.up"
    case .calculator: "function"
    case .files: "folder"
    case .quicklinks: "link"
    case .about: "info"
    }
  }

  var tint: Color {
    switch self {
    case .general: .gray
    case .apps: .blue
    case .emoji: .orange
    case .clipboard: .purple
    case .shortcuts: .pink
    case .calculator: .green
    case .files: .cyan
    case .quicklinks: .indigo
    case .about: .gray
    }
  }
}

private struct AppsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane(scrolls: false) {
      SettingsGroup {
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

private struct ShortcutsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsGroup {
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

private struct FilesSettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    SettingsPane {
      SettingsGroup {
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

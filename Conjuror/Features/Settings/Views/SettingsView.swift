import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  @ObservedObject var currencyRateStore: CurrencyRateStore
  @ObservedObject var launchAtLoginStore: LaunchAtLoginStore
  let fileAccessAuthorizer: FileAccessAuthorizer

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
      EmojiSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .shortcuts:
      ShortcutsSettingsView(store: store, hotKeyStore: hotKeyStore)
    case .calculator:
      CalculatorSettingsView(currencyRateStore: currencyRateStore)
    case .files:
      FilesSettingsView(
        store: store,
        hotKeyStore: hotKeyStore,
        accessAuthorizer: fileAccessAuthorizer
      )
    case .about:
      AboutSettingsView()
    }
  }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case emoji
  case shortcuts
  case calculator
  case files
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .emoji: "Emoji"
    case .shortcuts: "Shortcuts"
    case .calculator: "Calculator"
    case .files: "Files"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .emoji: "face.smiling"
    case .shortcuts: "square.stack.3d.up"
    case .calculator: "function"
    case .files: "folder"
    case .about: "info.circle"
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
  let accessAuthorizer: FileAccessAuthorizer

  var body: some View {
    SettingsPane {
      ModeShortcutSettingsRow(
        description: "Open the launcher directly in files mode.",
        action: .files,
        store: store,
        hotKeyStore: hotKeyStore
      )

      SettingsRow(
        title: "Protected folders",
        description: "Allow Conjuror to find files in Desktop, Documents, and Downloads."
      ) {
        Button("Grant Access") {
          accessAuthorizer.requestAccess()
        }
      }

      Text(
        "macOS controls access to protected folders. Approve each prompt to include that folder in file search results."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      Spacer()
    }
  }
}

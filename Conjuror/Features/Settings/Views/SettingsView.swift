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
      EmojiSettingsView(store: store)
    case .calculator:
      CalculatorSettingsView(currencyRateStore: currencyRateStore)
    case .files:
      FilesSettingsView(accessAuthorizer: fileAccessAuthorizer)
    case .about:
      AboutSettingsView()
    }
  }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case emoji
  case calculator
  case files
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .emoji: "Emoji"
    case .calculator: "Calculator"
    case .files: "Files"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .emoji: "face.smiling"
    case .calculator: "function"
    case .files: "folder"
    case .about: "info.circle"
    }
  }
}

private struct FilesSettingsView: View {
  @ObservedObject var accessAuthorizer: FileAccessAuthorizer

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Protected folders",
        description: "Allow Conjuror to find files in Desktop, Documents, and Downloads."
      ) {
        Button("Grant Access") {
          accessAuthorizer.requestAccess()
        }
      }

      Label(statusText, systemImage: statusImage)
        .font(.caption)
        .foregroundStyle(statusColor)

      if !accessAuthorizer.unavailableFolders.isEmpty {
        Text("Unavailable: \(accessAuthorizer.unavailableFolders.joined(separator: ", "))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text(
        "macOS controls access to protected folders. Approve each prompt to include that folder in file search results."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      Spacer()
    }
  }

  private var statusText: String {
    switch accessAuthorizer.status {
    case .notChecked: "Permission status has not been checked."
    case .granted: "Access granted to all protected folders."
    case .partiallyGranted: "Access granted to some protected folders."
    case .denied: "Access has not been granted."
    }
  }

  private var statusImage: String {
    switch accessAuthorizer.status {
    case .notChecked: "questionmark.circle"
    case .granted: "checkmark.circle.fill"
    case .partiallyGranted: "exclamationmark.triangle.fill"
    case .denied: "xmark.circle.fill"
    }
  }

  private var statusColor: Color {
    switch accessAuthorizer.status {
    case .notChecked: .secondary
    case .granted: .green
    case .partiallyGranted: .orange
    case .denied: .red
    }
  }
}

import SwiftUI

/// Lists app aliases and hot keys, and adds apps to customize.
struct ApplicationCustomizationsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore
  @ObservedObject var hotKeyStore: HotKeyStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Aliases and hotkeys").fontWeight(.medium)
        Spacer()
        Button("Add…") { showsPicker = true }
      }

      Text(
        "Type an alias to rank its app first. A hotkey opens the app, or hides it when in front."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

      ScrollView {
        LazyVStack(spacing: 8) {
          if rows.isEmpty {
            Text("No aliases or hotkeys")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          }
          ForEach(rows, id: \.path) { row in
            ApplicationCustomizationRow(
              path: row.path,
              name: row.name,
              application: installedApplications[row.path],
              customization: store.applicationCustomizations[row.path],
              isExcluded: store.excludedApplications[row.path] != nil,
              focusesAlias: row.path == focusedPath,
              store: store,
              hotKeyStore: hotKeyStore,
              onEdit: {
                if !addedPaths.contains(row.path) { addedPaths.append(row.path) }
              },
              onRemove: {
                addedPaths.removeAll { $0 == row.path }
                hotKeyStore.removeApplicationCustomization(at: row.path)
              }
            )
          }
        }
        .padding(8)
      }
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
    .sheet(isPresented: $showsPicker) {
      ApplicationPickerSheet(
        title: "Add an app",
        actionTitle: "Add",
        launcherStore: launcherStore,
        isAvailable: {
          store.applicationCustomizations[$0.persistenceKey] == nil
            && !addedPaths.contains($0.persistenceKey)
        },
        onSelect: { application in
          addedPaths.append(application.persistenceKey)
          focusedPath = application.persistenceKey
          showsPicker = false
        },
        onDone: { showsPicker = false }
      )
    }
  }

  @State private var showsPicker = false
  /// Apps added or edited in this session, kept listed while they have no alias or hotkey.
  @State private var addedPaths = [String]()
  @State private var focusedPath: String?

  private var installedApplications: [String: InstalledApplication] {
    Dictionary(
      launcherStore.applications.map { ($0.persistenceKey, $0) },
      uniquingKeysWith: { first, _ in first }
    )
  }

  private var rows: [(path: String, name: String)] {
    let stored = store.applicationCustomizations.map { (path: $0.key, name: $0.value.name) }
    let added = addedPaths.compactMap { path -> (path: String, name: String)? in
      guard store.applicationCustomizations[path] == nil,
        let application = installedApplications[path]
      else { return nil }

      return (path: path, name: application.displayName)
    }

    return (stored + added).sorted {
      let order = $0.name.localizedStandardCompare($1.name)
      return order == .orderedSame ? $0.path < $1.path : order == .orderedAscending
    }
  }
}

private struct ApplicationCustomizationRow: View {
  let path: String
  let name: String
  /// `nil` when the app is no longer installed, which leaves only removal.
  let application: InstalledApplication?
  let customization: ApplicationCustomization?
  let isExcluded: Bool
  let focusesAlias: Bool
  @ObservedObject var store: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  /// Keeps the row listed if an edit leaves it without an alias or hotkey.
  let onEdit: () -> Void
  let onRemove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        ApplicationLabel(name: name, path: path, status: status)
        Spacer(minLength: 4)

        if let application {
          TextField("Alias", text: $aliasText, prompt: Text("Alias"))
            .textFieldStyle(.roundedBorder)
            .frame(width: 72)
            .focused($isAliasFocused)
            .onChange(of: aliasText) { saveAlias(for: application) }
            .onChange(of: customization?.alias) { _, alias in
              // Follow changes made elsewhere, such as Reset to Defaults, unless the field
              // holds an invalid alias that wasn't saved.
              if errorMessage == nil, trimmedAlias != alias ?? "" { aliasText = alias ?? "" }
            }
            .accessibilityLabel("Alias for \(name)")

          ShortcutRecorder(
            configuration: customization?.hotKey,
            onChange: { configuration in
              onEdit()
              errorMessage = hotKeyStore.updateHotKey(configuration, for: application)
              return errorMessage == nil
            },
            onRecordingChange: hotKeyStore.setShortcutRecording
          )
          .frame(width: 116, height: 28)

          Button {
            onEdit()
            errorMessage = hotKeyStore.updateHotKey(nil, for: application)
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .buttonStyle(.borderless)
          .disabled(customization?.hotKey == nil)
          .help("Clear hotkey")
          .accessibilityLabel("Clear hotkey for \(name)")
        }

        Button(action: onRemove) {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .help("Remove")
        .accessibilityLabel("Remove \(name) from aliases and hotkeys")
      }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }
    }
    .onAppear {
      if focusesAlias { isAliasFocused = true }
    }
  }

  @State private var aliasText: String
  @State private var errorMessage: String?
  @FocusState private var isAliasFocused: Bool

  private var trimmedAlias: String {
    aliasText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var status: String? {
    if application == nil { return "Not installed" }

    return isExcluded ? "Excluded" : nil
  }

  init(
    path: String,
    name: String,
    application: InstalledApplication?,
    customization: ApplicationCustomization?,
    isExcluded: Bool,
    focusesAlias: Bool,
    store: SettingsStore,
    hotKeyStore: HotKeyStore,
    onEdit: @escaping () -> Void,
    onRemove: @escaping () -> Void
  ) {
    self.path = path
    self.name = name
    self.application = application
    self.customization = customization
    self.isExcluded = isExcluded
    self.focusesAlias = focusesAlias
    self.store = store
    self.hotKeyStore = hotKeyStore
    self.onEdit = onEdit
    self.onRemove = onRemove
    _aliasText = State(initialValue: customization?.alias ?? "")
  }

  /// Saves the alias as it's typed. An invalid one stays in the field with its error, unsaved.
  private func saveAlias(for application: InstalledApplication) {
    guard trimmedAlias != customization?.alias ?? "" else {
      errorMessage = nil
      return
    }

    onEdit()
    errorMessage = store.setAlias(trimmedAlias, for: application)
  }
}

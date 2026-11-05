import SwiftUI

/// A sheet listing installed apps that match a search, with an action button on each.
struct ApplicationPickerSheet: View {
  let title: String
  let actionTitle: String
  @ObservedObject var launcherStore: LauncherStore
  let isAvailable: (InstalledApplication) -> Bool
  let onSelect: (InstalledApplication) -> Void
  let onDone: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.headline)
      TextField("Search installed apps", text: $search)
        .textFieldStyle(.roundedBorder)

      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(availableApps) { application in
            HStack(spacing: 8) {
              ApplicationLabel(name: application.displayName, path: application.persistenceKey)
              Spacer(minLength: 4)
              Button(actionTitle) { onSelect(application) }
                .accessibilityLabel("\(actionTitle) \(application.displayName)")
            }
          }
          if availableApps.isEmpty {
            Text(launcherStore.isLoading ? "Loading apps…" : "No matching apps")
              .foregroundStyle(.secondary)
              .padding()
          }
        }
        .padding(4)
      }

      if let error = launcherStore.catalogErrorMessage {
        Text(error).font(.caption).foregroundStyle(.red)
        Button("Retry") { launcherStore.loadApplications() }
      }

      HStack {
        Spacer()
        Button("Done", action: onDone)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 400, height: 360)
  }

  @State private var search = ""

  private var availableApps: [InstalledApplication] {
    launcherStore.applications.filter {
      !$0.isSystemSettingsItem && isAvailable($0)
        && (search.isEmpty || $0.displayName.localizedStandardContains(search))
    }
    .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }
}

/// An app's icon, name, and path, with an optional status before the path.
struct ApplicationLabel: View {
  let name: String
  let path: String
  var status: String?

  var body: some View {
    HStack(spacing: 8) {
      Image(nsImage: ApplicationIconCache.shared.icon(for: URL(fileURLWithPath: path)))
        .resizable()
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(name).lineLimit(1)
        Text(status.map { "\($0) · \(path)" } ?? path)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .help(path)
    }
  }
}

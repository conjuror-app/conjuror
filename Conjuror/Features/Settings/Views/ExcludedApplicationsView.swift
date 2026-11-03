import SwiftUI

struct ExcludedApplicationsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Excluded apps").fontWeight(.medium)
        Spacer()
        Button("Add…") { showsPicker = true }
      }

      Text("Hide these apps from search and recent results.")
        .font(.caption)
        .foregroundStyle(.secondary)

      ScrollView {
        LazyVStack(spacing: 8) {
          if excludedApps.isEmpty {
            Text("No excluded apps")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          }
          ForEach(excludedApps, id: \.key) { path, name in
            HStack(spacing: 8) {
              applicationLabel(name: name, path: path)
              Spacer(minLength: 4)
              Button("Remove") { store.removeExcludedApplication(at: path) }
                .accessibilityLabel("Remove \(name) from excluded apps")
            }
          }
        }
        .padding(8)
      }
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }
    .sheet(isPresented: $showsPicker) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Exclude an app").font(.headline)
        TextField("Search installed apps", text: $search)
          .textFieldStyle(.roundedBorder)

        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(availableApps) { application in
              HStack(spacing: 8) {
                applicationLabel(name: application.displayName, path: application.persistenceKey)
                Spacer(minLength: 4)
                Button("Exclude") { store.excludeApplication(application) }
                  .accessibilityLabel("Exclude \(application.displayName)")
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
          Button("Done") { showsPicker = false }
            .keyboardShortcut(.defaultAction)
        }
      }
      .padding(20)
      .frame(width: 400, height: 360)
    }
    .onChange(of: showsPicker) { _, isPresented in
      if isPresented { search = "" }
    }
  }

  @State private var showsPicker = false
  @State private var search = ""

  private var excludedApps: [(key: String, value: String)] {
    store.excludedApplications.sorted {
      let order = $0.value.localizedStandardCompare($1.value)
      return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
    }
  }

  private var availableApps: [InstalledApplication] {
    launcherStore.applications.filter {
      !$0.isSystemSettingsItem && store.excludedApplications[$0.persistenceKey] == nil
        && (search.isEmpty || $0.displayName.localizedStandardContains(search))
    }
    .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }

  private func applicationLabel(name: String, path: String) -> some View {
    HStack(spacing: 8) {
      Image(nsImage: ApplicationIconCache.shared.icon(for: URL(fileURLWithPath: path)))
        .resizable()
        .frame(width: 24, height: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(name).lineLimit(1)
        Text(path)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .help(path)
    }
  }
}

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
              ApplicationLabel(name: name, path: path)
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
      ApplicationPickerSheet(
        title: "Exclude an app",
        actionTitle: "Exclude",
        launcherStore: launcherStore,
        isAvailable: { store.excludedApplications[$0.persistenceKey] == nil },
        onSelect: store.excludeApplication,
        onDone: { showsPicker = false }
      )
    }
  }

  @State private var showsPicker = false

  private var excludedApps: [(key: String, value: String)] {
    store.excludedApplications.sorted {
      let order = $0.value.localizedStandardCompare($1.value)
      return order == .orderedSame ? $0.key < $1.key : order == .orderedAscending
    }
  }
}

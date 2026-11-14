import SwiftUI

struct ExcludedApplicationsView: View {
  @ObservedObject var store: SettingsStore
  @ObservedObject var launcherStore: LauncherStore

  var body: some View {
    SettingsListCard(
      title: "Excluded apps",
      description: "Hide these apps from search and recent results.",
      emptyText: "No excluded apps",
      isEmpty: excludedApps.isEmpty,
      onAdd: { showsPicker = true }
    ) {
      ForEach(excludedApps, id: \.key) { path, name in
        HStack(spacing: 8) {
          ApplicationLabel(name: name, path: path)
          Spacer(minLength: 4)
          Button("Remove") { store.removeExcludedApplication(at: path) }
            .accessibilityLabel("Remove \(name) from excluded apps")
        }
      }
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

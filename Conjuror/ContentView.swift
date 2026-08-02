import SwiftUI

struct ContentView: View {
    @ObservedObject var store: LauncherStore
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LauncherSearchField(
                query: $store.query,
                onMoveSelection: store.moveSelection,
                onOpenSelected: store.openSelectedApplication
            )
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            resultHeader

            resultContent

            if let launchErrorMessage = store.launchErrorMessage {
                launchError(launchErrorMessage)
            }

            Divider()

            LauncherFooter(onQuit: onQuit)
        }
        .frame(width: 720, height: 470)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            WindowDragArea()
                .frame(height: 20)
                .accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
        .tint(.purple)
        .task {
            store.loadApplications()
        }
    }

    private var resultHeader: some View {
        HStack {
            Text(store.query.isEmpty ? "Applications" : "Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            if !store.isLoading {
                Text("\(store.filteredApplications.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var resultContent: some View {
        if store.isLoading, store.applications.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Finding installed applications…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let catalogErrorMessage = store.catalogErrorMessage {
            ContentUnavailableView {
                Label("Applications Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(catalogErrorMessage)
            } actions: {
                Button("Try Again", action: store.loadApplications)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.filteredApplications.isEmpty {
            if store.query.isEmpty {
                ContentUnavailableView(
                    "No Applications Found",
                    systemImage: "app.dashed"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView.search(text: store.query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.filteredApplications) { application in
                            LauncherResultRow(
                                application: application,
                                isSelected: application.id == store.selectedApplicationID,
                                onHover: { store.select(application) },
                                onOpen: { store.open(application) }
                            )
                            .id(application.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.selectedApplicationID) { _, selectedID in
                    guard let selectedID else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
    }

    private func launchError(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Button {
                store.clearLaunchError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Dismiss error")
        }
        .padding(.horizontal, 22)
        .frame(height: 34)
        .background(.red.opacity(0.08))
    }
}

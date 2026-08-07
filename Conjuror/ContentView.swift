import SwiftUI

enum LauncherLayout {
    static let width: CGFloat = 540
    static let collapsedHeight: CGFloat = 54
    static let expandedHeight: CGFloat = 360
}

struct ContentView: View {
    @ObservedObject var store: LauncherStore
    let hotKeyErrorMessage: String?
    let onHide: () -> Void
    let onExpansionChange: (Bool) -> Void

    private var isExpanded: Bool {
        !store.query.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            LauncherSearchField(
                query: $store.query,
                onMoveSelection: store.moveSelection,
                onOpenSelected: store.openSelectedApplication,
                focusRequest: store.focusRequest
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if isExpanded {
                Divider()

                if let hotKeyErrorMessage {
                    statusMessage(
                        hotKeyErrorMessage,
                        systemImage: "keyboard.badge.exclamationmark",
                        color: .orange
                    )
                }

                resultContent

                if let launchErrorMessage = store.launchErrorMessage {
                    launchError(launchErrorMessage)
                }
            }
        }
        .frame(
            width: LauncherLayout.width,
            height: isExpanded
                ? LauncherLayout.expandedHeight
                : LauncherLayout.collapsedHeight,
            alignment: .top
        )
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .task {
            store.loadApplications()
        }
        .onChange(of: isExpanded) {
            onExpansionChange(isExpanded)
        }
        .onExitCommand {
            if store.query.isEmpty {
                onHide()
            } else {
                store.query = ""
            }
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if store.isLoading, store.applications.isEmpty {
            minimalState {
                ProgressView()
                    .controlSize(.small)
                Text("Loading applications…")
            }
        } else if let catalogErrorMessage = store.catalogErrorMessage {
            minimalState {
                Image(systemName: "exclamationmark.triangle")
                Text(catalogErrorMessage)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Button("Try Again", action: store.loadApplications)
                    .controlSize(.small)
            }
        } else if store.filteredApplications.isEmpty {
            minimalState {
                Image(systemName: store.query.isEmpty ? "app.dashed" : "magnifyingglass")
                Text(store.query.isEmpty ? "No applications found" : "No matches")
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
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
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.selectionScrollRequest) {
                    guard let selectedID = store.selectedApplicationID else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
    }

    private func minimalState<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 6) {
            content()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func launchError(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)

            Text(message)
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
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(.red.opacity(0.06))
    }

    private func statusMessage(
        _ message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            Text(message)
                .lineLimit(1)

            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(color.opacity(0.06))
    }
}

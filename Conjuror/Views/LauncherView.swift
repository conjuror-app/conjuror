import SwiftUI

struct LauncherView: View {
    @ObservedObject var store: LauncherStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var hotKeyStore: HotKeyStore
    let onHide: () -> Void
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LauncherSearchField(
                query: $store.query,
                onOpenSelected: store.openSelectedApplication,
                focusRequest: store.focusRequest
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if isExpanded {
                Divider()

                if let hotKeyErrorMessage = hotKeyStore.registrationErrorMessage {
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
            height: contentHeight,
            alignment: .top
        )
        .modifier(LauncherSurfaceModifier())
        .task {
            store.loadApplications()
        }
        .onChange(of: contentHeight) {
            onHeightChange(contentHeight)
        }
        .onExitCommand {
            if store.query.isEmpty {
                onHide()
            } else {
                store.query = ""
            }
        }
    }

    private var isExpanded: Bool {
        !store.query.isEmpty
    }

    private var contentHeight: CGFloat {
        guard isExpanded else {
            return LauncherLayout.collapsedHeight
        }

        return LauncherLayout.expandedHeight(
            resultCount: store.filteredApplications.count,
            hasCatalogError: store.catalogErrorMessage != nil,
            hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
            hasLaunchError: store.launchErrorMessage != nil,
            maximumVisibleResults: settingsStore.maximumVisibleResults
        )
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
                    proxy.scrollTo(selectedID, anchor: .center)
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

enum LauncherLayout {
    static let width: CGFloat = 540
    static let collapsedHeight: CGFloat = 54
    private static let searchHeight: CGFloat = 52
    private static let dividerHeight: CGFloat = 1
    private static let resultRowHeight: CGFloat = 40
    private static let resultSpacing: CGFloat = 1
    private static let resultsVerticalPadding: CGFloat = 8

    static func expandedHeight(
        resultCount: Int,
        hasCatalogError: Bool,
        hasHotKeyError: Bool,
        hasLaunchError: Bool,
        maximumVisibleResults: Int
    ) -> CGFloat {
        let resultsHeight: CGFloat
        if hasCatalogError {
            resultsHeight = 104
        } else if resultCount == 0 {
            resultsHeight = 72
        } else {
            let visibleResultCount = min(resultCount, maximumVisibleResults)
            resultsHeight = resultsVerticalPadding
                + CGFloat(visibleResultCount) * resultRowHeight
                + CGFloat(max(visibleResultCount - 1, 0)) * resultSpacing
        }

        let statusHeight: CGFloat = hasHotKeyError ? 26 : 0
        let launchErrorHeight: CGFloat = hasLaunchError ? 26 : 0
        return searchHeight
            + dividerHeight
            + statusHeight
            + resultsHeight
            + launchErrorHeight
    }
}

private struct LauncherSurfaceModifier: ViewModifier {
    private let cornerRadius: CGFloat = 16

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .background(.regularMaterial, in: shape)
                .clipShape(shape)
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 1)
                }
        }
    }
}

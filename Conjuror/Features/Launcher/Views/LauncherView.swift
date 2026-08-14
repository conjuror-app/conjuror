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
        query: Binding(
          get: { store.query },
          set: { value in store.updateQuery(value) }
        ),
        mode: store.mode,
        onOpenSelected: store.openSelectedResult,
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

        if resultCount > 0, catalogErrorMessage == nil {
          actionFooter
        }

        if let actionErrorMessage {
          actionError(actionErrorMessage)
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
      if !store.query.isEmpty {
        store.updateQuery("")
      } else if store.mode != .applications {
        store.returnToApplicationsMode()
      } else {
        onHide()
      }
    }
  }

  private var isExpanded: Bool {
    store.mode != .applications || !store.query.isEmpty
  }

  private var resultCount: Int {
    switch store.mode {
    case .applications:
      store.filteredApplications.count + (store.calculatorResult == nil ? 0 : 1)
    case .emoji:
      store.displayedEmoji.count
    case .shortcuts:
      store.filteredShortcuts.count
    }
  }

  private var catalogErrorMessage: String? {
    switch store.mode {
    case .applications:
      store.catalogErrorMessage
    case .emoji:
      nil
    case .shortcuts:
      store.shortcutCatalogErrorMessage
    }
  }

  private var actionErrorMessage: String? {
    switch store.mode {
    case .applications:
      store.launchErrorMessage
    case .emoji:
      nil
    case .shortcuts:
      store.shortcutRunErrorMessage
    }
  }

  private var contentHeight: CGFloat {
    guard isExpanded else {
      return LauncherLayout.collapsedHeight
    }

    if store.mode == .emoji {
      return LauncherLayout.emojiExpandedHeight(
        itemCount: resultCount,
        hasRecentHeader: store.query.isEmpty && !store.recentEmoji.isEmpty,
        hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
        maximumVisibleResults: settingsStore.maximumVisibleResults
      )
    }

    return LauncherLayout.expandedHeight(
      resultCount: resultCount,
      hasCatalogError: catalogErrorMessage != nil,
      hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
      hasLaunchError: actionErrorMessage != nil,
      maximumVisibleResults: settingsStore.maximumVisibleResults
    )
  }

  @ViewBuilder
  private var resultContent: some View {
    switch store.mode {
    case .applications:
      applicationResults
    case .emoji:
      emojiResults
    case .shortcuts:
      shortcutResults
    }
  }

  private var actionFooterTitle: String {
    switch store.mode {
    case .applications:
      store.isCalculatorSelected ? "Copy result" : "Launch application"
    case .emoji:
      "Copy emoji"
    case .shortcuts:
      "Run shortcut"
    }
  }

  private var actionFooter: some View {
    VStack(spacing: 0) {
      Divider()

      HStack {
        Spacer()

        HStack(alignment: .center, spacing: 6) {
          Text(actionFooterTitle)
            .frame(height: 16, alignment: .center)

          Text("↵")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .frame(height: 16, alignment: .center)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .frame(height: 28)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Press Return to " + actionFooterTitle.lowercased())
  }

  @ViewBuilder
  private var applicationResults: some View {
    if let calculatorResult = store.calculatorResult {
      resultsScrollView(selectedID: store.selectedResultScrollID) {
        CalculatorResultRow(
          result: calculatorResult,
          isSelected: store.isCalculatorSelected,
          onHover: store.selectCalculatorResultOnHover,
          onCopy: store.copyCalculatorResult
        )
        .id(LauncherStore.calculatorResultScrollID)

        ForEach(store.filteredApplications) { application in
          applicationResultRow(application)
        }
      }
    } else if store.isLoading, store.applications.isEmpty {
      loadingState("Loading applications…")
    } else if let catalogErrorMessage = store.catalogErrorMessage {
      errorState(catalogErrorMessage, retry: store.loadApplications)
    } else if store.filteredApplications.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "app.dashed" : "magnifyingglass",
        message: store.query.isEmpty ? "No applications found" : "No matches"
      )
    } else {
      resultsScrollView(selectedID: store.selectedApplicationID) {
        ForEach(store.filteredApplications) { application in
          applicationResultRow(application)
        }
      }
    }
  }

  @ViewBuilder
  private var emojiResults: some View {
    if store.displayedEmoji.isEmpty {
      emptyState(systemImage: "magnifyingglass", message: "No matches")
    } else {
      resultsScrollView(selectedID: store.selectedEmojiID) {
        if store.query.isEmpty, !store.recentEmoji.isEmpty {
          Text("Recently Used")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: LauncherLayout.emojiRecentHeaderHeight)
            .padding(.horizontal, 4)
        }
        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible(), spacing: LauncherLayout.emojiRowSpacing),
            count: LauncherLayout.emojiColumnCount
          ),
          spacing: LauncherLayout.emojiRowSpacing
        ) {
          ForEach(store.displayedEmoji) { emoji in
            EmojiResultCell(
              emoji: emoji,
              isSelected: emoji.id == store.selectedEmojiID,
              onHover: { store.selectOnHover(emoji) },
              onCopy: {
                store.select(emoji); store.copySelectedEmoji()
              }
            )
            .id(emoji.id)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var shortcutResults: some View {
    if store.isLoadingShortcuts, store.shortcuts.isEmpty {
      loadingState("Loading shortcuts…")
    } else if let errorMessage = store.shortcutCatalogErrorMessage {
      errorState(errorMessage, retry: store.loadShortcuts)
    } else if store.filteredShortcuts.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "square.stack.3d.up" : "magnifyingglass",
        message: store.query.isEmpty ? "No shortcuts without input found" : "No matches"
      )
    } else {
      resultsScrollView(selectedID: store.selectedShortcutID) {
        ForEach(store.filteredShortcuts) { shortcut in
          ShortcutResultRow(
            shortcut: shortcut,
            isSelected: shortcut.id == store.selectedShortcutID,
            onHover: { store.selectOnHover(shortcut) },
            onRun: { store.run(shortcut) }
          )
          .id(shortcut.id)
        }
      }
    }
  }

  private func applicationResultRow(_ application: InstalledApplication) -> some View {
    ApplicationResultRow(
      application: application,
      isSelected: !store.isCalculatorSelected
        && application.id == store.selectedApplicationID,
      onHover: { store.selectOnHover(application) },
      onOpen: { store.open(application) }
    )
    .id(application.id)
  }

  private func resultsScrollView<Content: View>(
    selectedID: String?,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 1) {
          content()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
      }
      .scrollIndicators(.hidden)
      .onChange(of: store.selectionScrollRequest) {
        guard let selectedID else {
          return
        }
        proxy.scrollTo(selectedID, anchor: .center)
      }
    }
  }

  private func loadingState(_ message: String) -> some View {
    minimalState {
      ProgressView()
        .controlSize(.small)
      Text(message)
    }
  }

  private func errorState(_ message: String, retry: @escaping () -> Void) -> some View {
    minimalState {
      Image(systemName: "exclamationmark.triangle")
      Text(message)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      Button("Try Again", action: retry)
        .controlSize(.small)
    }
  }

  private func emptyState(systemImage: String, message: String) -> some View {
    minimalState {
      Image(systemName: systemImage)
      Text(message)
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

  private func actionError(_ message: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(.red)

      Text(message)
        .lineLimit(1)

      Spacer()

      Button {
        if store.mode == .applications {
          store.clearLaunchError()
        } else {
          store.clearShortcutRunError()
        }
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

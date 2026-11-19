import SwiftUI

struct LauncherView: View {
  @ObservedObject var store: LauncherStore
  @ObservedObject var settingsStore: SettingsStore
  @ObservedObject var hotKeyStore: HotKeyStore
  let onHide: () -> Void
  let onHeightChange: (CGFloat) -> Void

  var body: some View {
    VStack(spacing: 0) {
      searchField

      if isExpanded {
        if layout.appearance.usesDetachedResults {
          Color.clear.frame(height: layout.resultsSeparation)
        } else {
          Divider()
            .padding(.horizontal, 12)
        }

        resultsCard
      }
    }
    .frame(
      width: LauncherLayout.width,
      height: contentHeight,
      alignment: .top
    )
    .background {
      if !layout.appearance.usesDetachedResults {
        Color.clear.modifier(surface())
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .environment(\.colorScheme, layout.appearance.usesDarkMaterial ? .dark : colorScheme)
    .padding(LauncherLayout.windowMargin)
    .onChange(of: contentHeight, initial: true) {
      onHeightChange(contentHeight)
    }
    .onExitCommand(perform: escape)
  }

  @Environment(\.colorScheme) private var colorScheme

  private var searchField: some View {
    LauncherSearchField(
      query: Binding(
        get: { store.query },
        set: { value in store.updateQuery(value) }
      ),
      mode: store.mode,
      layout: layout,
      resultCount: showsSearchResults ? resultCount : nil,
      iconColor: LauncherAccentColor.color(
        for: settingsStore.launcherBorderStyle,
        customBorderColor: settingsStore.launcherCustomBorderColor
      ),
      onEscape: escape,
      escapeTitle: escapeTitle,
      onOpenSelected: store.openSelectedResult,
      focusRequest: store.focusRequest
    )
    .padding(.horizontal, layout.searchHorizontalPadding)
    .padding(.top, layout.searchTopPadding)
    .padding(.bottom, layout.searchBottomPadding)
    .background {
      if layout.appearance.usesDetachedResults {
        Color.clear.modifier(surface(isCapsule: true))
      }
    }
  }

  private var resultsCard: some View {
    VStack(spacing: 0) {
      if let hotKeyErrorMessage = hotKeyStore.registrationErrorMessage {
        statusMessage(
          hotKeyErrorMessage,
          systemImage: "keyboard.badge.exclamationmark",
          color: .orange
        )
      }

      LauncherResultsView(store: store, layout: layout)

      if layout.showsFooter, resultCount > 0, catalogErrorMessage == nil {
        actionFooter
      }

      if let pendingConfirmation = store.pendingConfirmation {
        confirmationBar(pendingConfirmation)
      } else if let actionErrorMessage = store.actionErrorMessage {
        actionError(actionErrorMessage)
      }
    }
    .background {
      if layout.appearance.usesDetachedResults {
        Color.clear.modifier(surface())
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: layout.appearance.usesDetachedResults ? 16 : 0))
  }

  private var showsSearchResults: Bool {
    store.mode != .applications || !store.query.isEmpty
  }

  private var isExpanded: Bool {
    guard showsSearchResults else { return false }
    guard layout.appearance.usesDetachedResults else { return true }

    return resultCount > 0 || catalogErrorMessage != nil || store.isLoadingResults
      || hotKeyStore.registrationErrorMessage != nil || store.actionErrorMessage != nil
      || store.pendingConfirmation != nil
  }

  private var resultCount: Int { store.resultCount }

  private var catalogErrorMessage: String? {
    switch store.mode {
    case .applications:
      store.catalogErrorMessage
    case .clipboard, .emoji, .running, .systemCommands:
      nil
    case .files:
      store.fileSearchErrorMessage
    case .shortcuts:
      store.shortcutCatalogErrorMessage
    }
  }

  private var contentHeight: CGFloat {
    guard isExpanded else {
      return layout.collapsedHeight
    }

    if store.mode == .emoji {
      return layout.emojiExpandedHeight(
        itemCount: resultCount,
        hasRecentHeader: store.query.isEmpty && !store.recentEmoji.isEmpty,
        hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
        maximumVisibleResults: settingsStore.maximumVisibleResults
      )
    }

    return layout.expandedHeight(
      resultCount: resultCount,
      hasCatalogError: catalogErrorMessage != nil,
      hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
      hasLaunchError: store.actionErrorMessage != nil || store.pendingConfirmation != nil,
      maximumVisibleResults: settingsStore.maximumVisibleResults
    )
  }

  private var layout: LauncherLayout {
    LauncherLayout(appearance: settingsStore.launcherAppearance)
  }

  private var actionFooterTitle: String {
    if let armedCommand = store.armedCommand {
      return "Confirm \(armedCommand.title)"
    }

    if store.isCalculatorSelected {
      return "Copy result"
    }

    if case .systemCommand = store.selectedResultID {
      return LauncherMode.systemCommands.actionTitle
    }

    if store.mode == .clipboard {
      return store.clipboardActionTitle
    }

    return store.mode.actionTitle
  }

  private var actionFooter: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, 12)

      HStack(spacing: 12) {
        HStack(spacing: 12) {
          if store.mode == .running {
            footerHint(keys: "⌘H", title: "Hide")
            footerHint(keys: "⌘⌫", title: "Quit")
          } else {
            footerHint(
              keys: store.mode.allowsHorizontalNavigation ? "←↑↓→" : "↑↓",
              title: "Navigate"
            )
            footerHint(keys: "Tab", title: "Mode")
          }
          footerHint(keys: "Esc", title: escapeTitle)

          if store.selectedRevealableURL != nil {
            footerHint(keys: "⌘↵", title: "Reveal")
          }

          if store.mode == .clipboard {
            footerHint(keys: "⌃X", title: "Delete")

            if store.pastesClipboardItems {
              footerHint(keys: "⌘↵", title: "Copy")
            }
          }
        }

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
      .frame(height: LauncherLayout.footerContentHeight)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Press Return to " + actionFooterTitle.lowercased())
  }

  private var escapeTitle: String {
    if store.armedCommand != nil || store.pendingConfirmation != nil { return "Cancel" }

    return store.query.isEmpty ? "Close" : "Clear"
  }

  private func escape() {
    if store.armedCommand != nil {
      store.cancelConfirmation()
    } else if store.pendingConfirmation != nil {
      store.cancelPendingAction()
    } else if !store.query.isEmpty {
      store.updateQuery("")
    } else {
      onHide()
    }
  }

  private func surface(isCapsule: Bool = false) -> LauncherSurfaceModifier {
    LauncherSurfaceModifier(
      borderStyle: settingsStore.launcherBorderStyle,
      customBorderColor: settingsStore.launcherCustomBorderColor,
      usesDarkMaterial: layout.appearance.usesDarkMaterial,
      isCapsule: isCapsule
    )
  }

  private func footerHint(keys: String, title: String) -> some View {
    HStack(spacing: 4) {
      Text(keys)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.tertiary)

      Text(title)
    }
  }

  private func actionError(_ message: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.circle")
        .foregroundStyle(.red)

      Text(message)
        .lineLimit(1)

      Spacer()

      Button {
        store.clearActionError()
      } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.plain)
      .help("Dismiss error")
    }
    .font(.caption)
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.statusHeight)
    .background(.red.opacity(0.06))
  }

  private func confirmationBar(_ confirmation: RunningApplicationConfirmation) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.red)

      Text(confirmation.message)
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer()

      Button("Cancel", action: store.cancelPendingAction)
        .help("Cancel (Esc)")

      Button(confirmation.confirmTitle, role: .destructive, action: store.confirmPendingAction)
        .help("\(confirmation.confirmTitle) (Return)")
    }
    .font(.caption)
    .controlSize(.small)
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.statusHeight)
    .background(.red.opacity(0.06))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(confirmation.message)
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
    .frame(height: LauncherLayout.statusHeight)
    .background(color.opacity(0.06))
  }
}

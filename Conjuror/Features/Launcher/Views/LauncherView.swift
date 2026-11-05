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
        iconColor: LauncherAccentColor.color(
          for: settingsStore.launcherBorderStyle,
          customBorderColor: settingsStore.launcherCustomBorderColor
        ),
        onOpenSelected: store.openSelectedResult,
        focusRequest: store.focusRequest
      )
      .padding(.horizontal, 12)
      .padding(.top, layout.searchTopPadding)
      .padding(.bottom, layout.searchBottomPadding)

      if isExpanded {
        Divider()
          .padding(.horizontal, 12)

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

        if let actionErrorMessage = store.actionErrorMessage {
          actionError(actionErrorMessage)
        }
      }
    }
    .frame(
      width: LauncherLayout.width,
      height: contentHeight,
      alignment: .top
    )
    .modifier(
      LauncherSurfaceModifier(
        borderStyle: settingsStore.launcherBorderStyle,
        customBorderColor: settingsStore.launcherCustomBorderColor
      )
    )
    .padding(LauncherLayout.windowMargin)
    .onChange(of: contentHeight) {
      onHeightChange(contentHeight)
    }
    .onExitCommand {
      if store.armedCommand != nil {
        store.cancelConfirmation()
      } else if !store.query.isEmpty {
        store.updateQuery("")
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
      store.filteredResults.count + (store.calculatorResult == nil ? 0 : 1)
    case .emoji:
      store.displayedEmoji.count
    case .files:
      store.fileResults.count
    case .shortcuts:
      store.filteredShortcuts.count
    case .systemCommands:
      store.filteredSystemCommands.count
    }
  }

  private var catalogErrorMessage: String? {
    switch store.mode {
    case .applications:
      store.catalogErrorMessage
    case .emoji, .systemCommands:
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
      hasLaunchError: store.actionErrorMessage != nil,
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

    return store.mode.actionTitle
  }

  private var actionFooter: some View {
    VStack(spacing: 0) {
      Divider()
        .padding(.horizontal, 12)

      HStack(spacing: 12) {
        HStack(spacing: 12) {
          footerHint(keys: store.mode.allowsHorizontalNavigation ? "←↑↓→" : "↑↓", title: "Navigate")
          footerHint(keys: "Tab", title: "Mode")
          footerHint(keys: "Esc", title: escapeTitle)

          if store.selectedRevealableURL != nil {
            footerHint(keys: "⌘↵", title: "Reveal")
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
    if store.armedCommand != nil { return "Cancel" }

    return store.query.isEmpty ? "Close" : "Clear"
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

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
        layout: layout,
        iconColor: accentColor,
        onOpenSelected: store.openSelectedResult,
        onCycleMode: store.cycleMode,
        onReturnToRoot: { store.updateQuery(";") },
        focusRequest: store.focusRequest
      )
      .padding(.horizontal, 12)
      .padding(.top, layout.searchTopPadding)
      .padding(.bottom, layout.searchBottomPadding)

      if isExpanded {
        Divider()
          .padding(.horizontal, layout.isCommandBar ? 0 : 12)

        if let hotKeyErrorMessage = hotKeyStore.registrationErrorMessage {
          statusMessage(
            hotKeyErrorMessage,
            systemImage: "keyboard.badge.exclamationmark",
            color: .orange
          )
        }

        LauncherResultsView(store: store, layout: layout)

        if layout.showsFooter, resultCount > 0, catalogErrorMessage == nil {
          if layout.isCommandBar {
            commandBarActionFooter
          } else {
            actionFooter
          }
        }

        if let pendingConfirmation = store.pendingConfirmation {
          confirmationBar(pendingConfirmation)
        } else if let actionErrorMessage = store.actionErrorMessage {
          actionError(actionErrorMessage)
        }
      }
    }
    .frame(
      width: layout.width,
      height: contentHeight,
      alignment: .top
    )
    .modifier(
      LauncherSurfaceModifier(
        appearance: settingsStore.launcherAppearance,
        borderStyle: settingsStore.launcherBorderStyle,
        customBorderColor: settingsStore.launcherCustomBorderColor
      )
    )
    .padding(LauncherLayout.windowMargin)
    .onChange(of: contentHeight) {
      onHeightChange(contentHeight)
    }
    .onChange(of: settingsStore.launcherAppearance) {
      onHeightChange(contentHeight)
    }
    .onExitCommand {
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
  }

  private var isExpanded: Bool {
    store.mode != .applications || !store.query.isEmpty
  }

  private var resultCount: Int {
    switch store.mode {
    case .applications:
      store.filteredResults.count + (store.calculatorResult == nil ? 0 : 1)
        + store.quicklinkResultCount
    case .clipboard:
      store.filteredClipboardItems.count
    case .emoji:
      store.displayedEmoji.count
    case .files:
      store.fileResults.count
    case .running:
      store.filteredRunningApplications.count
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
      extraResultsHeight: commandBarExtraResultsHeight,
      usesSplitDetail: usesSplitDetail,
      hasCatalogError: catalogErrorMessage != nil,
      hasHotKeyError: hotKeyStore.registrationErrorMessage != nil,
      hasLaunchError: store.actionErrorMessage != nil || store.pendingConfirmation != nil,
      maximumVisibleResults: settingsStore.maximumVisibleResults
    )
  }

  private var accentColor: Color {
    LauncherAccentColor.color(
      for: settingsStore.launcherBorderStyle,
      customBorderColor: settingsStore.launcherCustomBorderColor
    )
  }

  private var usesSplitDetail: Bool {
    layout.isCommandBar && (store.mode == .clipboard || store.mode == .files)
  }

  private var commandBarExtraResultsHeight: CGFloat {
    guard layout.isCommandBar else { return 0 }

    var extra: CGFloat = 0
    if store.mode == .applications {
      if store.calculatorResult != nil {
        extra += LauncherLayout.calculatorCardHeight - layout.resultRowHeight
      }
      var sectionCount = 0
      if store.keywordQuicklinkMatch != nil { sectionCount += 1 }
      if store.calculatorResult != nil { sectionCount += 1 }
      if !store.filteredResults.isEmpty { sectionCount += 1 }
      if !store.filteredQuicklinks.isEmpty || store.webSearchMatch != nil { sectionCount += 1 }
      extra += CGFloat(sectionCount) * LauncherLayout.sectionHeaderHeight
    } else if store.mode == .running || store.mode == .shortcuts || store.mode == .systemCommands {
      extra += LauncherLayout.sectionHeaderHeight
    }
    return extra
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

    if store.mode == .emoji {
      return store.emojiActionTitle
    }

    return store.mode.actionTitle
  }

  private var commandBarActionFooter: some View {
    VStack(spacing: 0) {
      Divider()

      HStack(spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: store.mode.systemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(
              accentColor == .secondary ? Color.accentColor : accentColor,
              in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )

          Text(store.mode.footerTitle)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer()

        HStack(spacing: 10) {
          HStack(spacing: 6) {
            Text(actionFooterTitle)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.primary.opacity(0.9))

            keycap("↵")
          }

          if let secondary = commandBarSecondaryHint {
            Rectangle()
              .fill(.primary.opacity(0.12))
              .frame(width: 1, height: 14)

            HStack(spacing: 6) {
              Text(secondary.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

              HStack(spacing: 3) {
                ForEach(secondary.keys, id: \.self) { key in
                  keycap(key)
                }
              }
            }
          }
        }
      }
      .padding(.horizontal, 14)
      .frame(height: layout.footerContentHeight)
      .background(.primary.opacity(0.03))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Press Return to " + actionFooterTitle.lowercased())
  }

  private var commandBarSecondaryHint: (title: String, keys: [String])? {
    if store.armedCommand != nil || store.pendingConfirmation != nil {
      return ("Cancel", ["Esc"])
    }
    if store.mode == .running {
      return ("Quit", ["⌘", "⌫"])
    }
    if store.mode == .clipboard {
      return store.pastesIntoPreviousApp ? ("Copy", ["⌘", "↵"]) : ("Delete", ["⌃", "X"])
    }
    if store.mode == .emoji, store.pastesIntoPreviousApp {
      return ("Copy", ["⌘", "↵"])
    }
    if store.selectedRevealableURL != nil {
      return ("Reveal", ["⌘", "↵"])
    }
    return ("Switch Mode", ["Tab"])
  }

  private func keycap(_ symbol: String) -> some View {
    Text(symbol)
      .font(.system(size: 10.5, weight: .medium, design: .rounded))
      .foregroundStyle(.primary.opacity(0.78))
      .padding(.horizontal, 5)
      .frame(minWidth: 20, minHeight: 20)
      .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
      }
      .accessibilityHidden(true)
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
          }

          if store.mode == .clipboard || store.mode == .emoji, store.pastesIntoPreviousApp {
            footerHint(keys: "⌘↵", title: "Copy")
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

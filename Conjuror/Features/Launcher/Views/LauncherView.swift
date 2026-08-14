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
          .padding(.horizontal, 12)

        if let hotKeyErrorMessage = hotKeyStore.registrationErrorMessage {
          statusMessage(
            hotKeyErrorMessage,
            systemImage: "keyboard.badge.exclamationmark",
            color: .orange
          )
        }

        LauncherResultsView(store: store)

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
    .padding(LauncherLayout.windowMargin)
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
        .padding(.horizontal, 12)

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

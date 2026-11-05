import SwiftUI

struct LauncherResultsView: View {
  @ObservedObject var store: LauncherStore
  let layout: LauncherLayout

  @ViewBuilder
  var body: some View {
    switch store.mode {
    case .applications:
      applicationResults
    case .emoji:
      emojiResults
    case .files:
      fileResults
    case .running:
      runningApplicationResults
    case .shortcuts:
      shortcutResults
    case .systemCommands:
      systemCommandResults
    }
  }

  @ViewBuilder
  private var applicationResults: some View {
    if store.calculatorResult != nil || store.quicklinkResultCount > 0 {
      applicationList
    } else if store.isLoading, store.applications.isEmpty {
      loadingState("Loading applications…")
    } else if let catalogErrorMessage = store.catalogErrorMessage {
      errorState(catalogErrorMessage, retry: store.loadApplications)
    } else if store.filteredResults.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "app.dashed" : "magnifyingglass",
        message: store.query.isEmpty ? "No applications found" : "No matches"
      )
    } else {
      applicationList
    }
  }

  private var applicationList: some View {
    resultsScrollView(selectedID: store.selectedResultID) {
      if let match = store.keywordQuicklinkMatch {
        quicklinkRow(match, id: .quicklink(match.quicklink.id))
      }

      if let calculatorResult = store.calculatorResult {
        CalculatorResultRow(
          result: calculatorResult,
          layout: layout,
          isSelected: store.isCalculatorSelected,
          onHover: { store.selectOnHover(.calculator) },
          onCopy: store.copyCalculatorResult
        )
        .id(LauncherResultID.calculator)
      }

      ForEach(store.filteredResults) { result in
        switch result {
        case .application(let application):
          ApplicationResultRow(
            application: application,
            layout: layout,
            isSelected: store.selectedResultID == result.id,
            onHover: { store.selectOnHover(result.id) },
            onOpen: { store.open(application) }
          )
          .id(result.id)
        case .systemCommand(let command):
          systemCommandRow(command)
        }
      }

      ForEach(store.filteredQuicklinks) { quicklink in
        quicklinkRow(
          QuicklinkMatcher.Match(quicklink: quicklink, argument: ""),
          id: .quicklink(quicklink.id)
        )
      }

      if let match = store.webSearchMatch {
        quicklinkRow(match, id: .webSearch)
      }
    }
  }

  @ViewBuilder
  private var systemCommandResults: some View {
    if store.filteredSystemCommands.isEmpty {
      emptyState(systemImage: "magnifyingglass", message: "No matches")
    } else {
      resultsScrollView(selectedID: store.selectedResultID) {
        ForEach(store.filteredSystemCommands) { command in
          systemCommandRow(command)
        }
      }
    }
  }

  @ViewBuilder
  private var emojiResults: some View {
    if store.displayedEmoji.isEmpty {
      emptyState(systemImage: "magnifyingglass", message: "No matches")
    } else {
      resultsScrollView(selectedID: store.selectedResultID) {
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
              layout: layout,
              isSelected: store.selectedResultID == .emoji(emoji.id),
              onHover: { store.selectOnHover(.emoji(emoji.id)) },
              onCopy: { store.copy(emoji) }
            )
            .id(LauncherResultID.emoji(emoji.id))
          }
        }
      }
    }
  }

  @ViewBuilder
  private var fileResults: some View {
    if store.isSearchingFiles, store.fileResults.isEmpty {
      loadingState("Searching files…")
    } else if let errorMessage = store.fileSearchErrorMessage {
      errorState(errorMessage, retry: { store.updateQuery(store.query) })
    } else if store.fileResults.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass",
        message: fileEmptyStateMessage
      )
    } else {
      resultsScrollView(selectedID: store.selectedResultID) {
        ForEach(store.fileResults) { file in
          FileResultRow(
            result: file,
            layout: layout,
            isSelected: store.selectedResultID == .file(file.id),
            onHover: { store.selectOnHover(.file(file.id)) },
            onOpen: { store.open(file) }
          )
          .id(LauncherResultID.file(file.id))
        }
      }
    }
  }

  private var fileEmptyStateMessage: String {
    let query = store.query.trimmingCharacters(in: .whitespacesAndNewlines)
    if query.isEmpty {
      return "Type to search files and folders"
    }
    if query.count < LauncherFileController.minimumQueryLength {
      return "Type at least 2 characters"
    }
    return "No matches"
  }

  @ViewBuilder
  private var runningApplicationResults: some View {
    if store.filteredRunningApplications.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "macwindow" : "magnifyingglass",
        message: store.query.isEmpty ? "No running apps" : "No matches"
      )
    } else {
      resultsScrollView(selectedID: store.selectedResultID) {
        ForEach(store.filteredRunningApplications) { application in
          RunningApplicationResultRow(
            application: application,
            layout: layout,
            isSelected: store.selectedResultID == .runningApplication(application.id),
            onHover: { store.selectOnHover(.runningApplication(application.id)) },
            onSwitch: { store.switchTo(application) }
          )
          .id(LauncherResultID.runningApplication(application.id))
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
      resultsScrollView(selectedID: store.selectedResultID) {
        ForEach(store.filteredShortcuts) { shortcut in
          ShortcutResultRow(
            shortcut: shortcut,
            layout: layout,
            isSelected: store.selectedResultID == .shortcut(shortcut.id),
            onHover: { store.selectOnHover(.shortcut(shortcut.id)) },
            onRun: { store.run(shortcut) }
          )
          .id(LauncherResultID.shortcut(shortcut.id))
        }
      }
    }
  }

  private func systemCommandRow(_ command: SystemCommand) -> some View {
    let id = LauncherResultID.systemCommand(command.id)

    return SystemCommandResultRow(
      command: command,
      layout: layout,
      isSelected: store.selectedResultID == id,
      isArmed: store.armedCommand == command,
      onHover: { store.selectOnHover(id) },
      onRun: { store.run(command) }
    )
    .id(id)
  }

  private func quicklinkRow(_ match: QuicklinkMatcher.Match, id: LauncherResultID) -> some View {
    QuicklinkResultRow(
      match: match,
      isWebSearch: id == .webSearch,
      layout: layout,
      isSelected: store.selectedResultID == id,
      onHover: { store.selectOnHover(id) },
      onOpen: { store.open(match) }
    )
    .id(id)
  }

  private func resultsScrollView<Content: View>(
    selectedID: LauncherResultID?,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: LauncherLayout.resultSpacing) {
          content()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, LauncherLayout.resultsVerticalPadding)
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
}

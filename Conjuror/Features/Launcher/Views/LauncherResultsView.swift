import SwiftUI

struct LauncherResultsView: View {
  @ObservedObject var store: LauncherStore
  let layout: LauncherLayout

  @ViewBuilder
  var body: some View {
    switch store.mode {
    case .applications:
      applicationResults
    case .clipboard:
      clipboardResults
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
        if layout.isCommandBar {
          sectionHeader("Quicklink")
        }
        quicklinkRow(match, id: .quicklink(match.quicklink.id))
      }

      if let calculatorResult = store.calculatorResult {
        if layout.isCommandBar {
          sectionHeader("Calculator")
        }
        CalculatorResultRow(
          result: calculatorResult,
          layout: layout,
          isSelected: store.isCalculatorSelected,
          onHover: { store.selectOnHover(.calculator) },
          onCopy: store.copyCalculatorResult
        )
        .id(LauncherResultID.calculator)
      }

      if layout.isCommandBar, !store.filteredResults.isEmpty {
        sectionHeader("Applications")
      }

      ForEach(store.filteredResults) { result in
        switch result {
        case .application(let application):
          ApplicationResultRow(
            application: application,
            alias: store.alias(for: application),
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

      if layout.isCommandBar, !store.filteredQuicklinks.isEmpty || store.webSearchMatch != nil {
        sectionHeader("Quicklinks")
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
        if layout.isCommandBar {
          sectionHeader("System Commands", detail: "\(store.filteredSystemCommands.count)")
        }
        ForEach(store.filteredSystemCommands) { command in
          systemCommandRow(command)
        }
      }
    }
  }

  @ViewBuilder
  private var clipboardResults: some View {
    if store.filteredClipboardItems.isEmpty {
      emptyState(
        systemImage: store.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
        message: store.query.isEmpty ? "Copy some text to see it here" : "No matches"
      )
    } else if layout.isCommandBar {
      HStack(spacing: 0) {
        resultsScrollView(selectedID: store.selectedResultID) {
          sectionHeader("Recent Copies", detail: "\(store.filteredClipboardItems.count)")
          ForEach(store.filteredClipboardItems) { item in
            ClipboardResultRow(
              item: item,
              layout: layout,
              isSelected: store.selectedResultID == .clipboardItem(item.id),
              actionTitle: store.clipboardActionTitle,
              onHover: { store.selectOnHover(.clipboardItem(item.id)) },
              onSelect: { store.paste(item) }
            )
            .id(LauncherResultID.clipboardItem(item.id))
          }
        }
        .frame(width: LauncherLayout.splitListWidth)

        Divider()

        clipboardDetailPane(selectedClipboardItem)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    } else {
      resultsScrollView(selectedID: store.selectedResultID) {
        ForEach(store.filteredClipboardItems) { item in
          ClipboardResultRow(
            item: item,
            layout: layout,
            isSelected: store.selectedResultID == .clipboardItem(item.id),
            actionTitle: store.clipboardActionTitle,
            onHover: { store.selectOnHover(.clipboardItem(item.id)) },
            onSelect: { store.paste(item) }
          )
          .id(LauncherResultID.clipboardItem(item.id))
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
              onChoose: { store.paste(emoji) }
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
    } else if layout.isCommandBar {
      HStack(spacing: 0) {
        resultsScrollView(selectedID: store.selectedResultID) {
          sectionHeader("Files", detail: "\(store.fileResults.count)")
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
        .frame(width: LauncherLayout.splitListWidth)

        Divider()

        fileDetailPane(selectedFileResult)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
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
        if layout.isCommandBar {
          sectionHeader(
            "Running Applications",
            detail: "\(store.filteredRunningApplications.count)"
          )
        }
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
        if layout.isCommandBar {
          sectionHeader("Apple Shortcuts", detail: "\(store.filteredShortcuts.count)")
        }
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

  private var selectedClipboardItem: ClipboardItem? {
    if case .clipboardItem(let id) = store.selectedResultID {
      return store.filteredClipboardItems.first { $0.id == id }
        ?? store.filteredClipboardItems.first
    }
    return store.filteredClipboardItems.first
  }

  private var selectedFileResult: FileSearchResult? {
    if case .file(let id) = store.selectedResultID {
      return store.fileResults.first { $0.id == id } ?? store.fileResults.first
    }
    return store.fileResults.first
  }

  private func sectionHeader(_ title: String, detail: String? = nil) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary.opacity(0.8))

      Spacer()

      if let detail {
        Text(detail)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.sectionHeaderHeight)
  }

  @ViewBuilder
  private func clipboardDetailPane(_ item: ClipboardItem?) -> some View {
    if let item {
      VStack(alignment: .leading, spacing: 12) {
        ScrollView {
          Text(item.text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          .primary.opacity(0.04),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(.primary.opacity(0.07), lineWidth: 0.5)
        }

        VStack(spacing: 6) {
          if let sourceName = item.source?.name {
            detailMetadataRow("Source", value: sourceName)
          }
          detailMetadataRow("Characters", value: "\(item.text.count)")
          detailMetadataRow(
            "Copied",
            value: item.lastCopiedAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
          )
        }
        .padding(.top, 2)
      }
      .padding(14)
      .background(.black.opacity(0.08))
    }
  }

  @ViewBuilder
  private func fileDetailPane(_ file: FileSearchResult?) -> some View {
    if let file {
      let icon = NSWorkspace.shared.icon(forFile: file.url.path)
      VStack(alignment: .leading, spacing: 14) {
        VStack(spacing: 8) {
          Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 56, height: 56)

          Text(file.displayName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        Divider()

        VStack(spacing: 6) {
          detailMetadataRow("Kind", value: file.isDirectory ? "Folder" : "File")
          detailMetadataRow("Location", value: file.parentPath)
          if let modificationDate = file.modificationDate {
            detailMetadataRow(
              "Modified",
              value: modificationDate.formatted(date: .abbreviated, time: .shortened)
            )
          }
        }
      }
      .padding(14)
      .background(.black.opacity(0.08))
    }
  }

  private func detailMetadataRow(_ label: String, value: String) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)

      Spacer(minLength: 8)

      Text(value)
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.primary.opacity(0.85))
        .lineLimit(1)
        .truncationMode(.middle)
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

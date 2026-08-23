import SwiftUI

struct LauncherResultsView: View {
  @ObservedObject var store: LauncherStore

  @ViewBuilder
  var body: some View {
    switch store.mode {
    case .applications:
      applicationResults
    case .emoji:
      emojiResults
    case .files:
      fileResults
    case .shortcuts:
      shortcutResults
    }
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
        .id(LauncherResultID.calculator)

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
      resultsScrollView(selectedID: store.selectedResultScrollID) {
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
      resultsScrollView(selectedID: store.selectedResultScrollID) {
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
      resultsScrollView(selectedID: store.selectedResultScrollID) {
        ForEach(store.fileResults) { file in
          FileResultRow(
            result: file,
            isSelected: file.id == store.selectedFileID,
            onHover: { store.selectOnHover(file) },
            onOpen: {
              store.select(file)
              store.openSelectedFile()
            }
          )
          .id(file.id)
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
      resultsScrollView(selectedID: store.selectedResultScrollID) {
        ForEach(store.filteredShortcuts) { shortcut in
          ShortcutResultRow(
            shortcut: shortcut,
            isSelected: shortcut.id == store.selectedShortcutID,
            onHover: { store.selectOnHover(shortcut) },
            onRun: { store.run(shortcut) }
          )
          .id(LauncherResultID.shortcut(shortcut.id))
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
    .id(LauncherResultID.application(application.id))
  }

  private func resultsScrollView<Content: View>(
    selectedID: LauncherResultID?,
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
}

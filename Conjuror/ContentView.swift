import SwiftUI

struct ContentView: View {
    let onQuit: () -> Void

    @State private var query = ""
    @State private var selectedItemID = LauncherItem.suggestions.first?.id

    private var filteredItems: [LauncherItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return LauncherItem.suggestions
        }

        return LauncherItem.suggestions.filter { item in
            item.searchableText.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            LauncherSearchField(
                query: $query,
                onMoveSelection: moveSelection
            )
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()

            HStack {
                Text(query.isEmpty ? "Suggestions" : "Results")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Text("\(filteredItems.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredItems) { item in
                                LauncherResultRow(
                                    item: item,
                                    isSelected: item.id == selectedItemID
                                ) {
                                    selectedItemID = item.id
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            Divider()

            LauncherFooter(onQuit: onQuit)
        }
        .frame(width: 720, height: 470)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            WindowDragArea()
                .frame(height: 20)
                .accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
        .tint(.purple)
        .onChange(of: query) {
            selectedItemID = filteredItems.first?.id
        }
        .onExitCommand {
            query = ""
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !filteredItems.isEmpty else {
            return
        }

        let currentIndex = filteredItems.firstIndex { $0.id == selectedItemID } ?? 0
        let nextIndex: Int

        switch direction {
        case .down:
            nextIndex = min(currentIndex + 1, filteredItems.count - 1)
        case .up:
            nextIndex = max(currentIndex - 1, 0)
        default:
            return
        }

        selectedItemID = filteredItems[nextIndex].id
    }
}

#Preview {
    ContentView(onQuit: {})
}

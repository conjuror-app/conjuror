import SwiftUI

struct LauncherSearchField: View {
    @Binding var query: String
    let onMoveSelection: (MoveCommandDirection) -> Void
    let onOpenSelected: () -> Void
    let focusRequest: Int

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search apps…", text: $query)
                .focused($isFocused)
                .font(.system(size: 19, weight: .regular))
                .textFieldStyle(.plain)
                .onMoveCommand(perform: onMoveSelection)
                .onSubmit(onOpenSelected)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 42)
        .task {
            isFocused = true
        }
        .onChange(of: focusRequest) {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }
}

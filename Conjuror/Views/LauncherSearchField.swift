import SwiftUI

struct LauncherSearchField: View {
    @Binding var query: String
    let onOpenSelected: () -> Void
    let focusRequest: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search apps…", text: $query)
                .focused($isFocused)
                .font(.system(size: 18, weight: .regular))
                .textFieldStyle(.plain)
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
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 38)
        .task {
            isFocused = true
        }
        .onChange(of: focusRequest) {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    @FocusState private var isFocused: Bool
}

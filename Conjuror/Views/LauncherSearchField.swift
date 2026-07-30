import SwiftUI

struct LauncherSearchField: View {
    @Binding var query: String
    let onMoveSelection: (MoveCommandDirection) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    .linearGradient(
                        colors: [.cyan, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            TextField("Search apps and commands…", text: $query)
                .focused($isFocused)
                .font(.system(size: 22, weight: .medium))
                .textFieldStyle(.plain)
                .onMoveCommand(perform: onMoveSelection)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .task {
            isFocused = true
        }
    }
}

import SwiftUI

struct QuicklinksSettingsView: View {
  @ObservedObject var store: SettingsStore

  var body: some View {
    SettingsPane {
      SettingsRow(
        title: "Web search fallback",
        description: "Search the web from the last result row, or press ⌥ Return."
      ) {
        Picker(
          "Web search fallback",
          selection: Binding(
            get: { store.webSearchQuicklink?.id },
            set: { store.setWebSearchQuicklink(id: $0) }
          )
        ) {
          Text("None").tag(Quicklink.ID?.none)
          ForEach(store.quicklinks.filter(\.acceptsQuery)) { quicklink in
            Text(quicklink.name).tag(Optional(quicklink.id))
          }
        }
        .labelsHidden()
        .frame(width: 160)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Quicklinks").fontWeight(.medium)
          Spacer()
          Button("Add…") { editedQuicklink = EditedQuicklink(quicklink: nil) }
        }

        Text("Type a keyword and search text, such as “gh swift testing”.")
          .font(.caption)
          .foregroundStyle(.secondary)

        ScrollView {
          LazyVStack(spacing: 8) {
            if store.quicklinks.isEmpty {
              Text("No quicklinks")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            ForEach(store.quicklinks) { quicklink in
              row(for: quicklink)
            }
          }
          .padding(8)
        }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
      }
      .frame(maxHeight: .infinity)

      HStack {
        Spacer()
        Button("Restore Built-ins") { store.restoreBuiltInQuicklinks() }
      }
    }
    .sheet(item: $editedQuicklink) { edited in
      QuicklinkEditorView(store: store, quicklink: edited.quicklink)
    }
  }

  @State private var editedQuicklink: EditedQuicklink?

  private func row(for quicklink: Quicklink) -> some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(quicklink.name).lineLimit(1)
          if let keyword = quicklink.keyword {
            Text(keyword)
              .font(.caption.monospaced())
              .padding(.horizontal, 5)
              .background(.quaternary, in: Capsule())
          }
        }
        Text(quicklink.urlTemplate)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .help(quicklink.urlTemplate)

      Spacer(minLength: 4)

      Button("Edit") { editedQuicklink = EditedQuicklink(quicklink: quicklink) }
        .accessibilityLabel("Edit \(quicklink.name)")
      Button("Remove") { store.removeQuicklink(id: quicklink.id) }
        .accessibilityLabel("Remove \(quicklink.name)")
    }
  }
}

/// The quicklink a sheet edits, or `nil` to add one.
private struct EditedQuicklink: Identifiable {
  let id = UUID()
  let quicklink: Quicklink?
}

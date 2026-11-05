import SwiftUI
import UniformTypeIdentifiers

struct QuicklinkEditorView: View {
  @ObservedObject var store: SettingsStore
  let quicklink: Quicklink?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(quicklink == nil ? "Add Quicklink" : "Edit Quicklink").font(.headline)

      Form {
        TextField("Name", text: $name, prompt: Text("GitHub"))
        TextField("Keyword", text: $keyword, prompt: Text("Optional, such as gh"))
        TextField(
          "URL",
          text: $urlTemplate,
          prompt: Text("https://github.com/search?q={query}")
        )
        LabeledContent("Open with") {
          HStack {
            Text(applicationName ?? "Default app").lineLimit(1)
            Spacer()
            if applicationPath != nil {
              Button("Use Default") { applicationPath = nil }
            }
            Button("Choose…") { showsApplicationPicker = true }
          }
        }
      }

      Text("{query} is replaced with the text typed after the keyword.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if let message = displayedError {
        Label(message, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }

      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Save", action: save)
          .keyboardShortcut(.defaultAction)
          .disabled(validationError != nil)
      }
    }
    .padding(20)
    .frame(width: 440)
    .fileImporter(
      isPresented: $showsApplicationPicker,
      allowedContentTypes: [.applicationBundle]
    ) { result in
      if case .success(let url) = result { applicationPath = url.path }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var keyword: String
  @State private var urlTemplate: String
  @State private var applicationPath: String?
  @State private var showsApplicationPicker = false
  @State private var saveError: String?
  private let id: Quicklink.ID

  private var draft: Quicklink {
    Quicklink(
      id: id,
      name: name,
      keyword: keyword,
      urlTemplate: urlTemplate,
      target: applicationPath.map { .application(path: $0) } ?? .defaultApplication
    )
  }

  private var validationError: String? {
    Quicklink.validationError(for: draft, among: store.quicklinks)
  }

  /// Hides the error for an untouched new quicklink, which is invalid only because it's empty.
  private var displayedError: String? {
    guard quicklink != nil || !name.isEmpty || !urlTemplate.isEmpty else { return saveError }

    return saveError ?? validationError
  }

  private var applicationName: String? {
    applicationPath.map { FileManager.default.displayName(atPath: $0) }
  }

  init(store: SettingsStore, quicklink: Quicklink?) {
    self.store = store
    self.quicklink = quicklink
    id = quicklink?.id ?? UUID()
    _name = State(initialValue: quicklink?.name ?? "")
    _keyword = State(initialValue: quicklink?.keyword ?? "")
    _urlTemplate = State(initialValue: quicklink?.urlTemplate ?? "")
    if case .application(let path) = quicklink?.target {
      _applicationPath = State(initialValue: path)
    } else {
      _applicationPath = State(initialValue: nil)
    }
  }

  private func save() {
    if let error = store.saveQuicklink(draft) {
      saveError = error
    } else {
      dismiss()
    }
  }
}

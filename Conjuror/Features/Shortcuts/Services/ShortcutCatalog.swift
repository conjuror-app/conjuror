import Foundation

struct ShortcutCatalog: ShortcutCatalogLoading {
  private static let cacheURL: URL? = {
    guard
      let applicationSupportURL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else { return nil }
    return
      applicationSupportURL
      .appendingPathComponent("Conjuror", isDirectory: true)
      .appendingPathComponent("Shortcuts.json", isDirectory: false)
  }()

  func load() async throws -> [AppleShortcut] {
    if let cachedShortcuts = Self.loadCache() {
      Task.detached(priority: .utility) {
        guard let shortcuts = try? Self.loadFresh() else { return }
        try? Self.saveCache(shortcuts)
      }
      return cachedShortcuts
    }

    let loadTask = Task.detached(priority: .userInitiated) {
      let shortcuts = try Self.loadFresh()
      try Task.checkCancellation()
      try? Self.saveCache(shortcuts)
      return shortcuts
    }
    return try await withTaskCancellationHandler {
      try await loadTask.value
    } onCancel: {
      loadTask.cancel()
    }
  }

  private static func loadCache() -> [AppleShortcut]? {
    guard let cacheURL,
      let data = try? Data(contentsOf: cacheURL),
      let shortcuts = try? JSONDecoder().decode([AppleShortcut].self, from: data)
    else { return nil }
    return shortcuts
  }

  private static func loadFresh() throws -> [AppleShortcut] {
    try ShortcutCatalogProcess.loadShortcuts()
  }

  private static func saveCache(_ shortcuts: [AppleShortcut]) throws {
    guard let cacheURL else { return }
    try FileManager.default.createDirectory(
      at: cacheURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(shortcuts)
    try data.write(to: cacheURL, options: .atomic)
  }
}

enum ShortcutCatalogProcess {
  private static let helperArgument = "--export-shortcut-catalog"

  static func runHelperIfRequested(
    arguments: [String] = CommandLine.arguments
  ) -> Int32? {
    guard arguments.contains(helperArgument) else { return nil }

    do {
      let shortcuts = try ShortcutsEventsBridge.loadShortcuts()
      FileHandle.standardOutput.write(try responseData(for: shortcuts))
      return 0
    } catch {
      FileHandle.standardError.write(Data(error.localizedDescription.utf8))
      return 1
    }
  }

  static func loadShortcuts() throws -> [AppleShortcut] {
    guard let executableURL = Bundle.main.executableURL else {
      throw ShortcutCatalogProcessError.missingExecutable
    }

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = executableURL
    process.arguments = [helperArgument]
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
      try process.run()
    } catch {
      throw ShortcutCatalogProcessError.launchFailed(error.localizedDescription)
    }

    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let message = String(decoding: errorOutput, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      throw ShortcutCatalogProcessError.helperFailed(message)
    }

    do {
      return try shortcuts(from: output)
    } catch {
      throw ShortcutCatalogProcessError.invalidResponse(error.localizedDescription)
    }
  }

  static func responseData(for shortcuts: [AppleShortcut]) throws -> Data {
    try JSONEncoder().encode(shortcuts.filter { !$0.acceptsInput })
  }

  static func shortcuts(from data: Data) throws -> [AppleShortcut] {
    try JSONDecoder().decode([AppleShortcut].self, from: data)
  }
}

protocol ShortcutCatalogLoading {
  @MainActor
  func load() async throws -> [AppleShortcut]
}

private enum ShortcutCatalogProcessError: LocalizedError {
  case helperFailed(String)
  case invalidResponse(String)
  case launchFailed(String)
  case missingExecutable

  var errorDescription: String? {
    switch self {
    case let .helperFailed(message):
      return message.isEmpty ? "The Shortcuts catalog helper failed." : message
    case let .invalidResponse(message):
      return "The Shortcuts catalog helper returned invalid data. \(message)"
    case let .launchFailed(message):
      return "Conjuror couldn’t start the Shortcuts catalog helper. \(message)"
    case .missingExecutable:
      return "Conjuror couldn’t locate the Shortcuts catalog helper."
    }
  }
}

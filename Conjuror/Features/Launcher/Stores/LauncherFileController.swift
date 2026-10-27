import Foundation

@MainActor
final class LauncherFileController {
  enum Update {
    case cleared
    case searching
    case results([FileSearchResult])
    case failed(Error)
  }

  static let minimumQueryLength = 2

  private let searcher: FileSearching
  private var task: Task<Void, Never>?

  init(searcher: FileSearching) {
    self.searcher = searcher
  }

  deinit {
    task?.cancel()
  }

  func search(query: String, onUpdate: @escaping (Update) -> Void) {
    task?.cancel()
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard query.count >= Self.minimumQueryLength else {
      onUpdate(.cleared)

      return
    }

    onUpdate(.searching)
    let searcher = searcher
    task = Task {
      do {
        try await Task.sleep(for: .milliseconds(200))
        let results = try await searcher.search(query: query)

        guard !Task.isCancelled else { return }

        onUpdate(.results(results))
      } catch is CancellationError {
      } catch {
        guard !Task.isCancelled else { return }

        onUpdate(.failed(error))
      }
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
  }
}

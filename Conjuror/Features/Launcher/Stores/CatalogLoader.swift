import Foundation

@MainActor
final class CatalogLoader<Value> {
  private var task: Task<Void, Never>?
  private var needsReload = false

  deinit {
    task?.cancel()
  }

  func load(
    operation: @escaping () async throws -> [Value],
    onLoadingChange: @escaping (Bool) -> Void,
    completion: @escaping (Result<[Value], Error>) -> Void
  ) {
    guard task == nil else {
      needsReload = true

      return
    }

    onLoadingChange(true)
    task = Task { [weak self] in
      repeat {
        self?.needsReload = false

        let result: Result<[Value], Error>?

        do {
          result = .success(try await operation())
        } catch is CancellationError {
          result = nil
        } catch {
          result = .failure(error)
        }

        guard !Task.isCancelled else { return }

        if let result {
          completion(result)
        }
      } while self?.needsReload == true

      self?.task = nil
      onLoadingChange(false)
    }
  }
}

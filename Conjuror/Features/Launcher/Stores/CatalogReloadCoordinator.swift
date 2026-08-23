import Foundation

@MainActor
final class CatalogReloadCoordinator<Value> {
  private var task: Task<Void, Never>?
  private var reloadRequested = false

  deinit {
    task?.cancel()
  }

  func load(
    operation: @escaping () async throws -> [Value],
    onLoadingChange: @escaping (Bool) -> Void,
    completion: @escaping (Result<[Value], Error>) -> Void
  ) {
    guard task == nil else {
      reloadRequested = true
      return
    }
    onLoadingChange(true)
    start(
      operation: operation,
      onLoadingChange: onLoadingChange,
      completion: completion
    )
  }

  func cancel() {
    task?.cancel()
    task = nil
    reloadRequested = false
  }

  private func start(
    operation: @escaping () async throws -> [Value],
    onLoadingChange: @escaping (Bool) -> Void,
    completion: @escaping (Result<[Value], Error>) -> Void
  ) {
    task = Task { [weak self] in
      let result: Result<[Value], Error>
      do {
        result = .success(try await operation())
      } catch is CancellationError {
        self?.finish(
          operation: operation,
          onLoadingChange: onLoadingChange,
          completion: completion
        )
        return
      } catch {
        result = .failure(error)
      }
      guard !Task.isCancelled else { return }
      completion(result)
      self?.finish(
        operation: operation,
        onLoadingChange: onLoadingChange,
        completion: completion
      )
    }
  }

  private func finish(
    operation: @escaping () async throws -> [Value],
    onLoadingChange: @escaping (Bool) -> Void,
    completion: @escaping (Result<[Value], Error>) -> Void
  ) {
    task = nil
    if reloadRequested {
      reloadRequested = false
      start(
        operation: operation,
        onLoadingChange: onLoadingChange,
        completion: completion
      )
    } else {
      onLoadingChange(false)
    }
  }
}

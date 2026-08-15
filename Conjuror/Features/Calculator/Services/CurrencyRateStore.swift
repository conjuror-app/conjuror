import Combine
import Foundation
import OSLog

@MainActor
final class CurrencyRateStore: ObservableObject {
  static let providerURL = URL(string: "https://frankfurter.dev")!
  static let refreshInterval: TimeInterval = 24 * 60 * 60

  private static let logger = Logger(subsystem: "Conjuror", category: "CurrencyRates")
  private static let enabledKey = UserDefaultsKey<Bool>(
    "settings.currencyConversionEnabled"
  )
  private static let retryInterval: TimeInterval = 15 * 60

  @Published private(set) var isEnabled: Bool
  @Published private(set) var rates: CurrencyRates?

  var source: CurrencySource {
    isEnabled ? .on(rates) : .off
  }

  private let cache: CurrencyRateCache
  private let client: CurrencyRateClient
  private let userDefaults: UserDefaults
  private var refreshTask: Task<Void, Never>?

  init(
    userDefaults: UserDefaults = .standard,
    cacheURL: URL? = nil,
    session: URLSession? = nil
  ) {
    self.userDefaults = userDefaults
    cache = CurrencyRateCache(url: cacheURL ?? CurrencyRateCache.defaultURL())
    client = CurrencyRateClient(session: session)
    isEnabled = userDefaults.value(for: Self.enabledKey) ?? false

    if isEnabled {
      do {
        rates = try cache.load()
      } catch CocoaError.fileReadNoSuchFile {
        // An empty cache is expected before the first successful refresh.
      } catch {
        Self.logger.error("Unable to load cached currency rates: \(error.localizedDescription)")
      }
    }
  }

  deinit {
    refreshTask?.cancel()
  }

  func start() {
    guard isEnabled else {
      return
    }
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let delay = await self?.nextRefreshDelay() else {
          return
        }
        try? await Task.sleep(for: .seconds(delay))
      }
    }
  }

  func setEnabled(_ enabled: Bool) {
    guard enabled != isEnabled else {
      return
    }
    isEnabled = enabled
    userDefaults.set(enabled, for: Self.enabledKey)
    if enabled {
      start()
    } else {
      refreshTask?.cancel()
      refreshTask = nil
      rates = nil
      do {
        try cache.remove()
      } catch {
        Self.logger.error("Unable to remove cached currency rates: \(error.localizedDescription)")
      }
    }
  }

  @discardableResult
  func refreshNow() async -> Bool {
    guard isEnabled else {
      return false
    }
    return await fetchAndStore()
  }

  private func nextRefreshDelay() async -> TimeInterval? {
    guard isEnabled else {
      return nil
    }

    let age = max(0, rates.map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity)
    if age < Self.refreshInterval {
      return Self.refreshInterval - age
    }
    return await fetchAndStore() ? Self.refreshInterval : Self.retryInterval
  }

  private func fetchAndStore() async -> Bool {
    guard isEnabled else {
      return false
    }

    do {
      guard let snapshot = try await client.fetch(), isEnabled else { return false }
      rates = snapshot
      try cache.save(snapshot)
      return true
    } catch is CancellationError {
      return false
    } catch {
      Self.logger.error("Unable to refresh currency rates: \(error.localizedDescription)")
      return false
    }
  }
}

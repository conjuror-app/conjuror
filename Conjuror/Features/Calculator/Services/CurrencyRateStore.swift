import Combine
import Foundation

@MainActor
final class CurrencyRateStore: ObservableObject {
  static let providerURL = URL(string: "https://frankfurter.dev")!
  static let refreshInterval: TimeInterval = 24 * 60 * 60

  private static let enabledKey = "settings.currencyConversionEnabled"
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
    isEnabled = userDefaults.bool(forKey: Self.enabledKey)

    if isEnabled {
      rates = try? cache.load()
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
    userDefaults.set(enabled, forKey: Self.enabledKey)
    if enabled {
      start()
    } else {
      refreshTask?.cancel()
      refreshTask = nil
      rates = nil
      try? cache.remove()
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
    } catch {
      return false
    }
  }
}

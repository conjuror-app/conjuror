import Combine
import Foundation

@MainActor
final class CurrencyRateStore: ObservableObject {
  static let providerURL = URL(string: "https://frankfurter.dev")!
  static let refreshInterval: TimeInterval = 24 * 60 * 60

  private static let endpoint = URL(
    string: "https://api.frankfurter.dev/v2/rates?base=USD"
  )!
  private static let enabledKey = "settings.currencyConversionEnabled"
  private static let retryInterval: TimeInterval = 15 * 60

  private static func defaultCacheURL() -> URL {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Conjuror", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory.appendingPathComponent("currency-rates.json")
  }

  private static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }

  @Published private(set) var isEnabled: Bool
  @Published private(set) var rates: CurrencyRates?

  var source: CurrencySource {
    isEnabled ? .on(rates) : .off
  }

  private let cacheURL: URL
  private let session: URLSession
  private let userDefaults: UserDefaults
  private var refreshTask: Task<Void, Never>?

  init(
    userDefaults: UserDefaults = .standard,
    cacheURL: URL? = nil,
    session: URLSession? = nil
  ) {
    self.userDefaults = userDefaults
    self.cacheURL = cacheURL ?? Self.defaultCacheURL()
    self.session = session ?? Self.makeSession()
    isEnabled = userDefaults.bool(forKey: Self.enabledKey)

    if isEnabled,
      let data = try? Data(contentsOf: self.cacheURL),
      let cachedRates = try? JSONDecoder().decode(CurrencyRates.self, from: data)
    {
      rates = cachedRates
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
      while !Task.isCancelled, let self, self.isEnabled {
        let age = max(0, self.rates.map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity)
        if age < Self.refreshInterval {
          try? await Task.sleep(for: .seconds(Self.refreshInterval - age))
          continue
        }
        let succeeded = await self.fetchAndStore()
        try? await Task.sleep(
          for: .seconds(succeeded ? Self.refreshInterval : Self.retryInterval)
        )
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
      try? FileManager.default.removeItem(at: cacheURL)
    }
  }

  @discardableResult
  func refreshNow() async -> Bool {
    guard isEnabled else {
      return false
    }
    return await fetchAndStore()
  }

  private func fetchAndStore() async -> Bool {
    guard isEnabled else {
      return false
    }

    do {
      let request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
      let (data, response) = try await session.data(for: request)
      guard isEnabled,
        let response = response as? HTTPURLResponse,
        response.statusCode == 200
      else {
        return false
      }
      let rows = try JSONDecoder().decode([RateRow].self, from: data)
      guard let first = rows.first else {
        return false
      }
      var table = [String: Double]()
      for row in rows
      where row.base == first.base && row.rate.isFinite && row.rate > 0 {
        table[row.quote] = row.rate
      }
      guard !table.isEmpty else {
        return false
      }
      let snapshot = CurrencyRates(
        base: first.base,
        rates: table,
        rateDate: first.date,
        fetchedAt: Date()
      )
      guard isEnabled else {
        return false
      }
      rates = snapshot
      let directory = cacheURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(snapshot).write(to: cacheURL, options: .atomic)
      return true
    } catch {
      return false
    }
  }
}

private struct RateRow: Decodable {
  let date: String
  let base: String
  let quote: String
  let rate: Double
}

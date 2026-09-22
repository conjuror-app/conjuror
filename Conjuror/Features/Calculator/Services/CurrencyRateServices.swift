import Foundation

struct CurrencyRateCache {
  static func defaultURL() -> URL {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Conjuror", isDirectory: true)
    return directory.appendingPathComponent("currency-rates.json")
  }

  let url: URL

  func load() throws -> CurrencyRates {
    let data = try Data(contentsOf: url)

    return try JSONDecoder().decode(CurrencyRates.self, from: data)
  }

  func save(_ rates: CurrencyRates) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(rates).write(to: url, options: .atomic)
  }

  func remove() throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }

    try FileManager.default.removeItem(at: url)
  }
}

struct CurrencyRateClient: Sendable {
  private static let endpoint = URL(
    string: "https://api.frankfurter.dev/v2/rates?base=USD"
  )!

  private let session: URLSession

  init(session: URLSession? = nil) {
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.urlCache = nil
      self.session = URLSession(configuration: configuration)
    }
  }

  func fetch() async throws -> CurrencyRates? {
    let request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
    let (data, response) = try await session.data(for: request)

    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
      return nil
    }

    let rows = try JSONDecoder().decode([CurrencyRateRow].self, from: data)

    guard let first = rows.first else { return nil }

    var table = [String: Double]()

    for row in rows where row.base == first.base && row.rate.isFinite && row.rate > 0 {
      table[row.quote] = row.rate
    }

    guard !table.isEmpty else { return nil }

    return CurrencyRates(
      base: first.base,
      rates: table,
      rateDate: first.date,
      fetchedAt: Date()
    )
  }
}

private struct CurrencyRateRow: Decodable {
  let date: String
  let base: String
  let quote: String
  let rate: Double
}

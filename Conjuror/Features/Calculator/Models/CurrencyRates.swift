import Foundation

struct CurrencyRates: Codable, Equatable, Sendable {
  let base: String
  let rates: [String: Double]
  let rateDate: String
  let fetchedAt: Date

  func rate(for code: String) -> Double? {
    let code = code.uppercased()
    if code == base {
      return 1
    }
    guard let rate = rates[code], rate.isFinite, rate > 0 else {
      return nil
    }
    return rate
  }

  func convert(_ amount: Double, from sourceCode: String, to targetCode: String) -> Double? {
    guard let sourceRate = rate(for: sourceCode),
      let targetRate = rate(for: targetCode)
    else {
      return nil
    }
    let value = amount / sourceRate * targetRate
    return value.isFinite ? value : nil
  }
}

enum CurrencySource: Equatable, Sendable {
  case off
  case on(CurrencyRates?)
}

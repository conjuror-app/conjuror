import Foundation

struct CalculatorRelativeDateEvaluator {
  private enum Direction {
    case ago
    case fromNow

    var multiplier: Double {
      switch self {
      case .ago: -1
      case .fromNow: 1
      }
    }
  }

  private enum Unit: String {
    case day
    case hour
    case minute
    case month
    case second
    case week
    case year

    var calendarComponent: Calendar.Component {
      switch self {
      case .day: .day
      case .hour: .hour
      case .minute: .minute
      case .month: .month
      case .second: .second
      case .week: .weekOfYear
      case .year: .year
      }
    }

    var secondsPerUnit: Double? {
      switch self {
      case .second: 1
      case .minute: 60
      case .hour: 3_600
      case .day: 86_400
      case .week: 604_800
      case .month, .year: nil
      }
    }
  }

  private let currentDate: Date
  private let timeZone: TimeZone
  private let localeIdentifier: String

  init(
    currentDate: Date,
    timeZone: TimeZone,
    localeIdentifier: String
  ) {
    self.currentDate = currentDate
    self.timeZone = timeZone
    self.localeIdentifier = localeIdentifier
  }

  func evaluate(_ expression: String) -> CalculatorResult? {
    let amountText: Substring
    let unitText: Substring
    let direction: Direction

    if let match = expression.wholeMatch(
      of:
        /(?i)(\d+(?:\.\d+)?|\.\d+)\s+(second|minute|hour|day|week|month|year)s?\s+(from\s+now|ago)/
    ) {
      amountText = match.1
      unitText = match.2
      direction = match.3.lowercased() == "ago" ? .ago : .fromNow
    } else if let match = expression.wholeMatch(
      of: /(?i)now\s*([+-])\s*(\d+(?:\.\d+)?|\.\d+)\s*(second|minute|hour|day|week|month|year)s?/
    ) {
      amountText = match.2
      unitText = match.3
      direction = match.1 == "-" ? .ago : .fromNow
    } else {
      return nil
    }

    guard let amount = Double(amountText),
      amount > 0,
      amount < Double(Int.max),
      amount.isFinite,
      let unit = Unit(rawValue: unitText.lowercased())
    else {
      return nil
    }

    guard let date = date(byAdding: amount * direction.multiplier, unit: unit) else {
      return nil
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: localeIdentifier)
    formatter.timeZone = timeZone
    formatter.dateStyle = .medium
    // Short times drop seconds, which would hide a change of seconds.
    formatter.timeStyle = unit == .second ? .medium : .short
    let formattedDate = formatter.string(from: date)

    return CalculatorResult(
      expression: expression,
      display: formattedDate,
      copyText: formattedDate
    )
  }

  private func date(byAdding amount: Double, unit: Unit) -> Date? {
    let wholeAmount = Int(amount.rounded(.towardZero))
    let fraction = amount - Double(wholeAmount)

    guard unit.secondsPerUnit != nil || fraction == 0 else {
      return nil
    }

    var calendar = Calendar.autoupdatingCurrent
    calendar.timeZone = timeZone

    guard
      let wholeDate = calendar.date(
        byAdding: unit.calendarComponent,
        value: wholeAmount,
        to: currentDate
      )
    else {
      return nil
    }

    guard let secondsPerUnit = unit.secondsPerUnit else {
      return wholeDate
    }

    return wholeDate.addingTimeInterval(fraction * secondsPerUnit)
  }
}

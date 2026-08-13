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
    case week
    case year

    var calendarComponent: Calendar.Component {
      switch self {
      case .day: .day
      case .hour: .hour
      case .minute: .minute
      case .month: .month
      case .week: .weekOfYear
      case .year: .year
      }
    }

    var secondsPerUnit: Double? {
      switch self {
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
    guard
      let match = expression.wholeMatch(
        of: /(?i)(\d+(?:\.\d+)?|\.\d+)\s+(minute|hour|day|week|month|year)s?\s+(from\s+now|ago)/
      ),
      let amount = Double(match.1),
      amount > 0,
      amount <= Double(Int.max),
      amount.isFinite,
      let unit = Unit(rawValue: String(match.2).lowercased())
    else {
      return nil
    }

    let direction: Direction = String(match.3).lowercased() == "ago" ? .ago : .fromNow
    guard let date = date(byAdding: amount * direction.multiplier, unit: unit) else {
      return nil
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: localeIdentifier)
    formatter.timeZone = timeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
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

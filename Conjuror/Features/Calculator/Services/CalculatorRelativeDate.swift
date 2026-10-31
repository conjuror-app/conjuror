import Foundation

struct CalculatorRelativeDateEvaluator {
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

  /// A date the user typed, which keeps its time only when it came from `now`.
  private struct Operand {
    let date: Date
    let includesTime: Bool
  }

  private static let dateFormats = [
    "d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy",
    "yyyy-MM-dd", "d MMM", "d MMMM", "MMM d", "MMMM d",
  ]

  private let currentDate: Date
  private let timeZone: TimeZone
  private let formattingOptions: CalculatorFormattingOptions
  private let calendar: Calendar

  init(
    currentDate: Date,
    timeZone: TimeZone,
    formattingOptions: CalculatorFormattingOptions
  ) {
    self.currentDate = currentDate
    self.timeZone = timeZone
    self.formattingOptions = formattingOptions

    var calendar = Calendar.autoupdatingCurrent
    calendar.timeZone = timeZone
    self.calendar = calendar
  }

  func evaluate(_ expression: String) -> CalculatorResult? {
    durationFromNow(expression) ?? offsetDate(expression) ?? difference(expression)
  }

  /// `5 days from now` and `2 weeks ago`.
  private func durationFromNow(_ expression: String) -> CalculatorResult? {
    guard
      let match = expression.wholeMatch(
        of:
          /(?i)(\d+(?:\.\d+)?|\.\d+)\s+(second|minute|hour|day|week|month|year)s?\s+(from\s+now|ago)/
      )
    else {
      return nil
    }

    return offsetResult(
      expression: expression,
      operand: Operand(date: currentDate, includesTime: true),
      isSubtracting: match.3.lowercased() == "ago",
      amountText: match.1,
      unitText: match.2
    )
  }

  /// `now + 2 hours` and `1 aug 2025 - 3 days`.
  private func offsetDate(_ expression: String) -> CalculatorResult? {
    guard
      let match = expression.wholeMatch(
        of:
          /(?i)(.+?)\s*([+-])\s*(\d+(?:\.\d+)?|\.\d+)\s*(second|minute|hour|day|week|month|year)s?/
      ),
      let operand = operand(from: match.1)
    else {
      return nil
    }

    return offsetResult(
      expression: expression,
      operand: operand,
      isSubtracting: match.2 == "-",
      amountText: match.3,
      unitText: match.4
    )
  }

  /// `now - 1 aug 2025`, in days unless a unit follows, as in `now - 1 aug 2025 in weeks`.
  private func difference(_ expression: String) -> CalculatorResult? {
    guard
      let match = expression.wholeMatch(
        of:
          /(?i)(.+?)\s*-\s*(.+?)(?:\s+(?:in|to)\s+(second|minute|hour|day|week|month|year)s?)?/
      ),
      let end = operand(from: match.1),
      let start = operand(from: match.2)
    else {
      return nil
    }

    let unit = match.3.flatMap { Unit(rawValue: $0.lowercased()) } ?? .day

    guard let value = difference(from: start, to: end, in: unit) else {
      return nil
    }

    let formatter = CalculatorNumberFormatter(options: formattingOptions)
    let unitName = abs(value) == 1 ? unit.rawValue : unit.rawValue + "s"

    guard let display = formatter.string(from: value, usesGroupingSeparator: true),
      let copyText = formatter.string(from: value, usesGroupingSeparator: false)
    else {
      return nil
    }

    return CalculatorResult(
      expression: expression,
      display: "\(display) \(unitName)",
      copyText: "\(copyText) \(unitName)"
    )
  }

  private func offsetResult(
    expression: String,
    operand: Operand,
    isSubtracting: Bool,
    amountText: Substring,
    unitText: Substring
  ) -> CalculatorResult? {
    guard let amount = Double(amountText),
      amount > 0,
      amount < Double(Int.max),
      amount.isFinite,
      let unit = Unit(rawValue: unitText.lowercased()),
      let date = date(byAdding: isSubtracting ? -amount : amount, unit: unit, to: operand.date)
    else {
      return nil
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: formattingOptions.localeIdentifier)
    formatter.timeZone = timeZone
    formatter.dateStyle = .medium

    // Short times drop seconds, which would hide a change of seconds. A typed date without a time
    // stays a date unless the offset moves it within the day.
    formatter.timeStyle =
      switch unit {
      case .second: .medium
      case .minute, .hour: .short
      case .day, .week, .month, .year:
        operand.includesTime || date != calendar.startOfDay(for: date) ? .short : .none
      }

    let formattedDate = formatter.string(from: date)

    return CalculatorResult(
      expression: expression,
      display: formattedDate,
      copyText: formattedDate
    )
  }

  private func operand(from text: Substring) -> Operand? {
    let text = text.trimmingCharacters(in: .whitespaces).lowercased()
    let today = calendar.startOfDay(for: currentDate)

    switch text {
    case "now":
      return Operand(date: currentDate, includesTime: true)
    case "today":
      return Operand(date: today, includesTime: false)
    case "tomorrow", "yesterday":
      return calendar.date(byAdding: .day, value: text == "tomorrow" ? 1 : -1, to: today)
        .map { Operand(date: $0, includesTime: false) }
    default:
      // Skip date parsing for plain numbers, as in `10 - 5`.
      guard text.contains(where: \.isLetter) || text.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
      else {
        return nil
      }

      var gregorian = Calendar(identifier: .gregorian)
      gregorian.timeZone = timeZone
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.calendar = gregorian
      formatter.timeZone = timeZone
      formatter.isLenient = false
      // Dates without a year fall in the current one.
      formatter.defaultDate = today

      return Self.dateFormats.lazy.compactMap { format in
        formatter.dateFormat = format

        return formatter.date(from: text)
      }
      .first
      .map { Operand(date: $0, includesTime: false) }
    }
  }

  private func date(byAdding amount: Double, unit: Unit, to start: Date) -> Date? {
    let wholeAmount = Int(amount.rounded(.towardZero))
    let fraction = amount - Double(wholeAmount)

    guard unit.secondsPerUnit != nil || fraction == 0,
      let wholeDate = calendar.date(byAdding: unit.calendarComponent, value: wholeAmount, to: start)
    else {
      return nil
    }

    guard let secondsPerUnit = unit.secondsPerUnit else {
      return wholeDate
    }

    return wholeDate.addingTimeInterval(fraction * secondsPerUnit)
  }

  private func difference(from start: Operand, to end: Operand, in unit: Unit) -> Double? {
    switch unit {
    case .month, .year:
      // Whole calendar months and years, as in an age.
      return calendar.dateComponents([unit.calendarComponent], from: start.date, to: end.date)
        .value(for: unit.calendarComponent)
        .map(Double.init)
    case .second, .minute, .hour, .day, .week:
      guard let secondsPerUnit = unit.secondsPerUnit else { return nil }

      // Dates without times count calendar days, so daylight saving time doesn't add a fraction.
      if !start.includesTime, !end.includesTime,
        let days = calendar.dateComponents([.day], from: start.date, to: end.date).day
      {
        return Double(days) * 86_400 / secondsPerUnit
      }

      return end.date.timeIntervalSince(start.date) / secondsPerUnit
    }
  }
}

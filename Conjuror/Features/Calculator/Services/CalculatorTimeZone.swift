import Foundation

struct CalculatorTimeZoneEvaluator {
  private static let fixedOffsets = [
    "UTC": 0,
    "GMT": 0,
    "WET": 0,
    "WEST": 3_600,
    "BST": 3_600,
    "CET": 3_600,
    "CEST": 7_200,
    "EET": 7_200,
    "EEST": 10_800,
    "MSK": 10_800,
    "MSD": 14_400,
    "IRST": 12_600,
    "JST": 32_400,
    "NZST": 43_200,
    "NZDT": 46_800,
    "EST": -18_000,
    "EDT": -14_400,
    "CST": -21_600,
    "CDT": -18_000,
    "MST": -25_200,
    "MDT": -21_600,
    "PST": -28_800,
    "PDT": -25_200,
    "AKST": -32_400,
    "AKDT": -28_800,
    "AST": -14_400,
    "ADT": -10_800,
    "NST": -12_600,
    "NDT": -9_000,
    "CLT": -14_400,
    "CLST": -10_800,
    "BRT": -10_800,
    "BRST": -7_200,
  ]

  let currentDate: Date
  let currentTimeZone: TimeZone

  init(
    currentDate: Date = Date(),
    currentTimeZone: TimeZone = .current
  ) {
    self.currentDate = currentDate
    self.currentTimeZone = currentTimeZone
  }

  func evaluate(_ expression: String) -> CalculatorResult? {
    guard let conversion = parse(expression),
      let date = date(for: conversion.time, in: conversion.sourceTimeZone)
    else {
      return nil
    }

    let sourceBadge =
      conversion.sourceAbbreviation
      ?? conversion.sourceTimeZone.abbreviation(for: date)
      ?? conversion.sourceTimeZone.identifier
    let targetBadge =
      conversion.targetAbbreviation
      ?? conversion.targetTimeZone.abbreviation(for: date)
      ?? conversion.targetTimeZone.identifier
    let sourceDisplay = format(
      date,
      in: conversion.sourceTimeZone,
      usesTwelveHourClock: conversion.time.usesTwelveHourClock
    )
    let display = format(
      date,
      in: conversion.targetTimeZone,
      usesTwelveHourClock: conversion.time.usesTwelveHourClock
    )

    return CalculatorResult(
      expression: expression,
      display: display,
      copyText: display + " " + targetBadge,
      sourceDisplay: sourceDisplay,
      sourceBadge: sourceBadge,
      targetBadge: targetBadge
    )
  }

  private func parse(_ expression: String) -> Conversion? {
    let normalized = CalculatorInput.normalizeConversion(expression)
    let lowercased = normalized.lowercased()
    let connector = lowercased.range(of: " to ") ?? lowercased.range(of: " in ")

    let left: String
    let targetTimeZone: TimeZone
    let targetAbbreviation: String?

    if let connector {
      left = String(normalized[..<connector.lowerBound])
        .trimmingCharacters(in: .whitespaces)
      let targetName = String(normalized[connector.upperBound...])
        .trimmingCharacters(in: .whitespaces)
      guard let explicitTargetTimeZone = timeZone(abbreviated: targetName) else {
        return nil
      }

      targetTimeZone = explicitTargetTimeZone
      targetAbbreviation = targetName.uppercased()
    } else {
      left = normalized
      targetTimeZone = currentTimeZone
      targetAbbreviation = nil
    }

    let words = left.split(whereSeparator: \.isWhitespace)

    guard !words.isEmpty else {
      return nil
    }

    var sourceTimeZone = currentTimeZone
    var sourceAbbreviation: String?
    var timeText = left

    if let sourceName = words.last.map(String.init),
      let explicitSourceTimeZone = timeZone(abbreviated: sourceName)
    {
      sourceTimeZone = explicitSourceTimeZone
      sourceAbbreviation = sourceName.uppercased()
      timeText = words.dropLast().joined(separator: " ")
    } else if connector == nil {
      return nil
    }

    guard let time = parseTime(timeText) else {
      return nil
    }

    return Conversion(
      time: time,
      sourceTimeZone: sourceTimeZone,
      sourceAbbreviation: sourceAbbreviation,
      targetTimeZone: targetTimeZone,
      targetAbbreviation: targetAbbreviation
    )
  }

  private func parseTime(_ text: String) -> ParsedTime? {
    let pattern = #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$"#

    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    else {
      return nil
    }

    let range = NSRange(text.startIndex..., in: text)

    guard let match = regex.firstMatch(in: text, range: range),
      match.range == range,
      let hourRange = Range(match.range(at: 1), in: text),
      let hour = Int(text[hourRange])
    else {
      return nil
    }

    let minute: Int

    if let minuteRange = Range(match.range(at: 2), in: text) {
      guard let parsedMinute = Int(text[minuteRange]) else {
        return nil
      }

      minute = parsedMinute
    } else {
      minute = 0
    }

    guard minute < 60 else {
      return nil
    }

    if let meridiemRange = Range(match.range(at: 3), in: text) {
      guard (1...12).contains(hour) else {
        return nil
      }

      let meridiem = text[meridiemRange].lowercased()
      let normalizedHour = (hour % 12) + (meridiem == "pm" ? 12 : 0)

      return ParsedTime(hour: normalizedHour, minute: minute, usesTwelveHourClock: true)
    }

    guard (0...23).contains(hour) else {
      return nil
    }

    return ParsedTime(hour: hour, minute: minute, usesTwelveHourClock: false)
  }

  private func timeZone(abbreviated text: String) -> TimeZone? {
    let abbreviation = text.uppercased()

    if let offset = Self.fixedOffsets[abbreviation] {
      return TimeZone(secondsFromGMT: offset)
    }

    guard TimeZone.abbreviationDictionary[abbreviation] != nil,
      let timeZone = TimeZone(abbreviation: abbreviation)
    else {
      return nil
    }

    return TimeZone(secondsFromGMT: timeZone.secondsFromGMT(for: currentDate))
  }

  private func date(for time: ParsedTime, in timeZone: TimeZone) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let day = calendar.dateComponents([.year, .month, .day], from: currentDate)
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = timeZone
    components.year = day.year
    components.month = day.month
    components.day = day.day
    components.hour = time.hour
    components.minute = time.minute

    return calendar.date(from: components)
  }

  private func format(
    _ date: Date,
    in timeZone: TimeZone,
    usesTwelveHourClock: Bool
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = usesTwelveHourClock ? "h:mm a" : "HH:mm"
    let value = formatter.string(from: date)

    return usesTwelveHourClock ? value.lowercased() : value
  }
}

private extension CalculatorTimeZoneEvaluator {
  struct Conversion {
    let time: ParsedTime
    let sourceTimeZone: TimeZone
    let sourceAbbreviation: String?
    let targetTimeZone: TimeZone
    let targetAbbreviation: String?
  }

  struct ParsedTime {
    let hour: Int
    let minute: Int
    let usesTwelveHourClock: Bool
  }
}

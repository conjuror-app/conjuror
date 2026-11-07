import Foundation

enum ClipboardHistoryRetention: String, CaseIterable, Identifiable, Sendable {
  case day
  case week
  case month
  case threeMonths
  case forever

  static let `default` = Self.month

  var id: Self { self }

  var title: String {
    switch self {
    case .day: "1 Day"
    case .week: "7 Days"
    case .month: "30 Days"
    case .threeMonths: "3 Months"
    case .forever: "Forever"
    }
  }

  /// The oldest last-copied date kept at `date`, or `nil` when items never expire.
  func cutoff(before date: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .day: calendar.date(byAdding: .day, value: -1, to: date)
    case .week: calendar.date(byAdding: .day, value: -7, to: date)
    case .month: calendar.date(byAdding: .day, value: -30, to: date)
    case .threeMonths: calendar.date(byAdding: .month, value: -3, to: date)
    case .forever: nil
    }
  }
}

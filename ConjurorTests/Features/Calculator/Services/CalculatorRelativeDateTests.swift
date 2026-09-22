import Foundation
import Testing

@testable import Conjuror

extension CalculatorEngineTests {
  @Test("Calculator engine: relative dates support calendar units in both directions")
  func testRelativeDatesSupportCalendarUnitsInBothDirections() {
    let engine = relativeDateEngine(
      currentDate: "2024-02-29T15:30:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 1, 2024 at 3:30 PM")
    #expect(engine.evaluate("2 weeks ago")?.copyText == "Feb 15, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 month from now")?.copyText == "Mar 29, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 year ago")?.copyText == "Feb 28, 2023 at 3:30 PM")
  }

  @Test("Calculator engine: relative dates support fractional duration units")
  func testRelativeDatesSupportFractionalDurationUnits() {
    let engine = relativeDateEngine(
      currentDate: "2026-08-12T12:00:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1.5 hours from now")?.copyText == "Aug 12, 2026 at 1:30 PM")
    #expect(engine.evaluate("90 minutes ago")?.copyText == "Aug 12, 2026 at 10:30 AM")
    #expect(engine.evaluate(".5 days from now")?.copyText == "Aug 13, 2026 at 12:00 AM")
    #expect(engine.evaluate("1.5 weeks ago")?.copyText == "Aug 2, 2026 at 12:00 AM")
  }

  @Test("Calculator engine: whole days use calendar arithmetic across daylight saving time")
  func testRelativeDatesUseCalendarArithmeticAcrossDaylightSavingTime() {
    let engine = relativeDateEngine(
      currentDate: "2026-03-28T12:00:00Z",
      timeZone: TimeZone(identifier: "Europe/London")!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 29, 2026 at 12:00 PM")
  }

  @Test("Calculator engine: invalid relative dates stay silent")
  func testInvalidRelativeDatesStaySilent() {
    #expect((engine.evaluate("1.5 months from now")) == nil)
    #expect((engine.evaluate("0 days from now")) == nil)
    #expect((engine.evaluate("-5 days from now")) == nil)
    #expect((engine.evaluate("5 days later")) == nil)
    #expect((engine.evaluate("days from now")) == nil)
    #expect(engine.evaluate("9223372036854775807 days from now") == nil)
    #expect(engine.evaluate("9223372036854775808 days ago") == nil)
  }
}

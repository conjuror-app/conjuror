import Foundation
import Testing

@testable import Conjuror

extension CalculatorEngineTests {
  @Test("Relative dates support calendar units in both directions")
  func testRelativeDates() {
    let engine = relativeDateEngine(
      currentDate: "2024-02-29T15:30:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 1, 2024 at 3:30 PM")
    #expect(engine.evaluate("2 weeks ago")?.copyText == "Feb 15, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 month from now")?.copyText == "Mar 29, 2024 at 3:30 PM")
    #expect(engine.evaluate("1 year ago")?.copyText == "Feb 28, 2023 at 3:30 PM")
  }

  @Test("Relative dates support fractional duration units")
  func testFractionalDates() {
    let engine = relativeDateEngine(
      currentDate: "2026-08-12T12:00:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1.5 hours from now")?.copyText == "Aug 12, 2026 at 1:30 PM")
    #expect(engine.evaluate("90 minutes ago")?.copyText == "Aug 12, 2026 at 10:30 AM")
    #expect(engine.evaluate(".5 days from now")?.copyText == "Aug 13, 2026 at 12:00 AM")
    #expect(engine.evaluate("1.5 weeks ago")?.copyText == "Aug 2, 2026 at 12:00 AM")
  }

  @Test("Now plus or minus a duration matches the from-now and ago forms")
  func testNowArithmetic() {
    let engine = relativeDateEngine(
      currentDate: "2024-02-29T15:30:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("now + 1 day")?.copyText == "Mar 1, 2024 at 3:30 PM")
    #expect(engine.evaluate("NOW - 2 weeks")?.copyText == "Feb 15, 2024 at 3:30 PM")
    #expect(engine.evaluate("now+1.5hours")?.copyText == "Feb 29, 2024 at 5:00 PM")
    #expect(engine.evaluate("now + 1 year")?.copyText == "Feb 28, 2025 at 3:30 PM")
  }

  @Test("Second offsets show the seconds in the result")
  func testSecondOffsets() {
    let engine = relativeDateEngine(
      currentDate: "2026-08-12T12:00:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("now + 90 seconds")?.copyText == "Aug 12, 2026 at 12:01:30 PM")
    #expect(engine.evaluate("45 seconds ago")?.copyText == "Aug 12, 2026 at 11:59:15 AM")
  }

  @Test("Date differences default to days and accept a unit")
  func testDateDifferences() {
    let engine = relativeDateEngine(
      currentDate: "2026-10-15T10:28:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("now - 1 aug 2025 in days")?.copyText == "440.4361111 days")
    #expect(engine.evaluate("now - 1 aug 2025")?.copyText == "440.4361111 days")
    #expect(engine.evaluate("1 jan 2026 - 2025-01-01")?.copyText == "365 days")
    #expect(engine.evaluate("tomorrow - today")?.copyText == "1 day")
    #expect(engine.evaluate("now - 1 aug 2025 in months")?.copyText == "14 months")
    #expect(engine.evaluate("today - 1 january 1990 in years")?.copyText == "36 years")
    #expect(engine.evaluate("1 aug 2025 - 15 aug 2025 in weeks")?.copyText == "-2 weeks")
  }

  @Test("Typed dates accept duration offsets and stay dates without a time")
  func testTypedDateOffsets() {
    let engine = relativeDateEngine(
      currentDate: "2026-10-15T10:28:00Z",
      timeZone: TimeZone(secondsFromGMT: 0)!
    )

    #expect(engine.evaluate("1 aug 2025 + 30 days")?.copyText == "Aug 31, 2025")
    #expect(engine.evaluate("2025-08-01 - 1 week")?.copyText == "Jul 25, 2025")
    #expect(engine.evaluate("aug 1 - 3 days")?.copyText == "Jul 29, 2026")
    #expect(engine.evaluate("tomorrow + 12 hours")?.copyText == "Oct 16, 2026 at 12:00 PM")
  }

  @Test("Whole days use calendar arithmetic across daylight saving time")
  func testDaylightSavingDates() {
    let engine = relativeDateEngine(
      currentDate: "2026-03-28T12:00:00Z",
      timeZone: TimeZone(identifier: "Europe/London")!
    )

    #expect(engine.evaluate("1 day from now")?.copyText == "Mar 29, 2026 at 12:00 PM")
  }

  @Test("Invalid relative dates stay silent")
  func testInvalidRelativeDatesStaySilent() {
    #expect(engine.evaluate("1.5 months from now") == nil)
    #expect(engine.evaluate("0 days from now") == nil)
    #expect(engine.evaluate("-5 days from now") == nil)
    #expect(engine.evaluate("5 days later") == nil)
    #expect(engine.evaluate("days from now") == nil)
    #expect(engine.evaluate("now") == nil)
    #expect(engine.evaluate("now + 1.5 months") == nil)
    #expect(engine.evaluate("now * 2 days") == nil)
    #expect(engine.evaluate("1 aug 2025 + 1.5 months") == nil)
    #expect(engine.evaluate("banana - 1 aug 2025") == nil)
    #expect(engine.evaluate("10 - 5")?.copyText == "5")
    #expect(engine.evaluate("9223372036854775807 days from now") == nil)
    #expect(engine.evaluate("9223372036854775808 days ago") == nil)
  }
}

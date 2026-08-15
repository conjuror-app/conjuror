import Foundation
import Testing

@testable import Conjuror

extension CalculatorEngineTests {
  @Test("Calculator engine: explicit time-zone abbreviations use fixed offsets")
  func testExplicitTimeZoneAbbreviationsUseFixedOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("10:00 BST in EST")

    #expect(result?.sourceDisplay == "10:00")
    #expect(result?.sourceBadge == "BST")
    #expect(result?.display == "04:00")
    #expect(result?.targetBadge == "EST")
    #expect(result?.copyText == "04:00 EST")
  }

  @Test("Calculator engine: standard and daylight abbreviations use distinct offsets")
  func testStandardAndDaylightAbbreviationsHaveDistinctOffsets() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("10:00 EST in GMT")?.copyText == "15:00 GMT")
    #expect(engine.evaluate("10:00 EDT in GMT")?.copyText == "14:00 GMT")
    #expect(engine.evaluate("10:00 PST in GMT")?.copyText == "18:00 GMT")
    #expect(engine.evaluate("10:00 PDT in GMT")?.copyText == "17:00 GMT")
    #expect(engine.evaluate("10:00 CET in GMT")?.copyText == "09:00 GMT")
    #expect(engine.evaluate("10:00 CEST in GMT")?.copyText == "08:00 GMT")
    #expect(engine.evaluate("10:00 NZST in GMT")?.copyText == "22:00 GMT")
    #expect(engine.evaluate("10:00 NZDT in GMT")?.copyText == "21:00 GMT")
    #expect(engine.evaluate("10:00 NST in GMT")?.copyText == "13:30 GMT")
    #expect(engine.evaluate("10:00 NDT in GMT")?.copyText == "12:30 GMT")
  }

  @Test("Calculator engine: other macOS time-zone abbreviations are supported")
  func testTimeZoneConversionSupportsOtherMacOSTimeZoneAbbreviations() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("10:00 EAT in IST")?.copyText == "12:30 IST")
    #expect(engine.evaluate("10:00 SGT in WAT")?.copyText == "03:00 WAT")
  }

  @Test("Calculator engine: bare time-zone input converts to the current time zone")
  func testBareTimeZoneInputConvertsToCurrentTimeZone() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("12:00 PST")

    #expect(result?.sourceDisplay == "12:00")
    #expect(result?.sourceBadge == "PST")
    #expect(result?.display == "21:00")
    #expect(result?.targetBadge == "BST")
    #expect(result?.copyText == "21:00 BST")
  }

  @Test("Calculator engine: current time zone is used when the source is omitted")
  func testTimeZoneConversionUsesCurrentTimeZoneWhenSourceIsOmitted() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(identifier: "Europe/London")!)

    let result = engine.evaluate("1:00 pm in PDT")

    #expect(result?.sourceBadge == "BST")
    #expect(result?.display == "5:00 am")
    #expect(result?.copyText == "5:00 am PDT")
  }

  @Test("Calculator engine: current context refreshes between evaluations")
  func testTimeZoneConversionRefreshesCurrentContextBetweenEvaluations() {
    var currentDate = ISO8601DateFormatter().date(from: "2026-08-12T12:00:00Z")!
    var currentTimeZone = TimeZone(identifier: "Europe/London")!
    let engine = CalculatorEngine(
      currentDate: { currentDate },
      currentTimeZone: { currentTimeZone }
    )

    #expect(engine.evaluate("10:00 in UTC")?.copyText == "09:00 UTC")

    currentDate = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
    #expect(engine.evaluate("10:00 in UTC")?.copyText == "10:00 UTC")

    currentTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    #expect(engine.evaluate("10:00 in UTC")?.copyText == "01:00 UTC")
  }

  @Test("Calculator engine: time-zone connectors and day wrapping are supported")
  func testTimeZoneConversionSupportsConnectorsAndWrapsAcrossDays() {
    let engine = timeZoneEngine(currentTimeZone: TimeZone(secondsFromGMT: 0)!)

    #expect(engine.evaluate("23:30 UTC → JST")?.copyText == "08:30 JST")
    #expect(engine.evaluate("9am GMT -> PDT")?.copyText == "2:00 am PDT")
  }

  @Test("Calculator engine: invalid time-zone input stays silent")
  func testInvalidTimeZoneInputStaysSilent() {
    #expect((engine.evaluate("25:00 GMT in EST")) == nil)
    #expect((engine.evaluate("10:60 GMT in EST")) == nil)
    #expect((engine.evaluate("10:00 XYZ in EST")) == nil)
    #expect((engine.evaluate("10:00 GMT in XYZ")) == nil)
    #expect((engine.evaluate("10:00 in")) == nil)
    #expect((engine.evaluate("10:00")) == nil)
  }
}

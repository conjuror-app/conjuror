import Foundation

enum CalculatorQuantityDimension: Equatable {
  case data
  case duration
  case length
  case mass
  case temperature
  case volume
}

struct CalculatorUnit: Equatable {
  let id: String
  let dimension: CalculatorQuantityDimension
  let symbol: String
  let aliases: [String]
  let scaleToBase: Double
  let offsetToBase: Double

  init(
    id: String,
    dimension: CalculatorQuantityDimension,
    symbol: String,
    aliases: [String],
    scaleToBase: Double,
    offsetToBase: Double = 0
  ) {
    self.id = id
    self.dimension = dimension
    self.symbol = symbol
    self.aliases = aliases
    self.scaleToBase = scaleToBase
    self.offsetToBase = offsetToBase
  }

  func convertFromBase(_ value: Double) -> Double {
    (value - offsetToBase) / scaleToBase
  }

  func convertToBase(_ value: Double) -> Double {
    value * scaleToBase + offsetToBase
  }
}

enum CalculatorUnitRegistry {
  private static let unitsByAlias: [String: CalculatorUnit] = {
    var result = [String: CalculatorUnit]()
    for unit in units {
      for alias in unit.aliases {
        result[alias.lowercased()] = unit
      }
    }
    return result
  }()

  private static let defaultTargetIDs = [
    "meter": "foot",
    "kilometer": "mile",
    "centimeter": "inch",
    "millimeter": "inch",
    "inch": "centimeter",
    "foot": "meter",
    "yard": "meter",
    "mile": "kilometer",
    "kilogram": "pound",
    "gram": "ounce",
    "milligram": "gram",
    "pound": "kilogram",
    "ounce": "gram",
    "second": "minute",
    "minute": "hour",
    "hour": "minute",
    "day": "hour",
    "week": "day",
    "celsius": "fahrenheit",
    "fahrenheit": "celsius",
    "kelvin": "celsius",
    "liter": "gallon",
    "milliliter": "fluid-ounce",
    "teaspoon": "milliliter",
    "tablespoon": "milliliter",
    "cup": "milliliter",
    "fluid-ounce": "milliliter",
    "pint": "liter",
    "quart": "liter",
    "gallon": "liter",
    "byte": "bit",
    "bit": "byte",
    "kilobyte": "kibibyte",
    "megabyte": "mebibyte",
    "gigabyte": "gibibyte",
    "terabyte": "tebibyte",
    "kibibyte": "kilobyte",
    "mebibyte": "megabyte",
    "gibibyte": "gigabyte",
    "tebibyte": "terabyte",
  ]

  private static let units = [
    CalculatorUnit(
      id: "meter",
      dimension: .length,
      symbol: "m",
      aliases: ["m", "meter", "meters", "metre", "metres"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "kilometer",
      dimension: .length,
      symbol: "km",
      aliases: ["km", "kilometer", "kilometers", "kilometre", "kilometres"],
      scaleToBase: 1_000
    ),
    CalculatorUnit(
      id: "centimeter",
      dimension: .length,
      symbol: "cm",
      aliases: ["cm", "centimeter", "centimeters", "centimetre", "centimetres"],
      scaleToBase: 0.01
    ),
    CalculatorUnit(
      id: "millimeter",
      dimension: .length,
      symbol: "mm",
      aliases: ["mm", "millimeter", "millimeters", "millimetre", "millimetres"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "inch",
      dimension: .length,
      symbol: "in",
      aliases: ["in", "inch", "inches"],
      scaleToBase: 0.0254
    ),
    CalculatorUnit(
      id: "foot",
      dimension: .length,
      symbol: "ft",
      aliases: ["ft", "foot", "feet"],
      scaleToBase: 0.3048
    ),
    CalculatorUnit(
      id: "yard",
      dimension: .length,
      symbol: "yd",
      aliases: ["yd", "yard", "yards"],
      scaleToBase: 0.9144
    ),
    CalculatorUnit(
      id: "mile",
      dimension: .length,
      symbol: "mi",
      aliases: ["mi", "mile", "miles"],
      scaleToBase: 1_609.344
    ),
    CalculatorUnit(
      id: "kilogram",
      dimension: .mass,
      symbol: "kg",
      aliases: ["kg", "kilogram", "kilograms"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "gram",
      dimension: .mass,
      symbol: "g",
      aliases: ["g", "gram", "grams"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "milligram",
      dimension: .mass,
      symbol: "mg",
      aliases: ["mg", "milligram", "milligrams"],
      scaleToBase: 0.000_001
    ),
    CalculatorUnit(
      id: "pound",
      dimension: .mass,
      symbol: "lb",
      aliases: ["lb", "lbs", "pound", "pounds"],
      scaleToBase: 0.453_592_37
    ),
    CalculatorUnit(
      id: "ounce",
      dimension: .mass,
      symbol: "oz",
      aliases: ["oz", "ounce", "ounces"],
      scaleToBase: 0.028_349_523_125
    ),
    CalculatorUnit(
      id: "second",
      dimension: .duration,
      symbol: "s",
      aliases: ["s", "sec", "secs", "second", "seconds"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "minute",
      dimension: .duration,
      symbol: "min",
      aliases: ["min", "mins", "minute", "minutes"],
      scaleToBase: 60
    ),
    CalculatorUnit(
      id: "hour",
      dimension: .duration,
      symbol: "hr",
      aliases: ["h", "hr", "hrs", "hour", "hours"],
      scaleToBase: 3_600
    ),
    CalculatorUnit(
      id: "day",
      dimension: .duration,
      symbol: "day",
      aliases: ["d", "day", "days"],
      scaleToBase: 86_400
    ),
    CalculatorUnit(
      id: "week",
      dimension: .duration,
      symbol: "wk",
      aliases: ["wk", "wks", "week", "weeks"],
      scaleToBase: 604_800
    ),
    CalculatorUnit(
      id: "celsius",
      dimension: .temperature,
      symbol: "°C",
      aliases: ["c", "°c", "celsius"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "fahrenheit",
      dimension: .temperature,
      symbol: "°F",
      aliases: ["f", "°f", "fahrenheit"],
      scaleToBase: 5.0 / 9.0,
      offsetToBase: -160.0 / 9.0
    ),
    CalculatorUnit(
      id: "kelvin",
      dimension: .temperature,
      symbol: "K",
      aliases: ["k", "kelvin"],
      scaleToBase: 1,
      offsetToBase: -273.15
    ),
    CalculatorUnit(
      id: "liter",
      dimension: .volume,
      symbol: "L",
      aliases: ["l", "liter", "liters", "litre", "litres"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "milliliter",
      dimension: .volume,
      symbol: "mL",
      aliases: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"],
      scaleToBase: 0.001
    ),
    CalculatorUnit(
      id: "teaspoon",
      dimension: .volume,
      symbol: "US tsp",
      aliases: ["tsp", "teaspoon", "teaspoons"],
      scaleToBase: 0.004_928_921_593_75
    ),
    CalculatorUnit(
      id: "tablespoon",
      dimension: .volume,
      symbol: "US tbsp",
      aliases: ["tbsp", "tablespoon", "tablespoons"],
      scaleToBase: 0.014_786_764_781_25
    ),
    CalculatorUnit(
      id: "cup",
      dimension: .volume,
      symbol: "US cup",
      aliases: ["cup", "cups"],
      scaleToBase: 0.236_588_236_5
    ),
    CalculatorUnit(
      id: "fluid-ounce",
      dimension: .volume,
      symbol: "US fl oz",
      aliases: ["floz"],
      scaleToBase: 0.029_573_529_562_5
    ),
    CalculatorUnit(
      id: "pint",
      dimension: .volume,
      symbol: "US pt",
      aliases: ["pt", "pint", "pints"],
      scaleToBase: 0.473_176_473
    ),
    CalculatorUnit(
      id: "quart",
      dimension: .volume,
      symbol: "US qt",
      aliases: ["qt", "quart", "quarts"],
      scaleToBase: 0.946_352_946
    ),
    CalculatorUnit(
      id: "gallon",
      dimension: .volume,
      symbol: "US gal",
      aliases: ["gal", "gallon", "gallons"],
      scaleToBase: 3.785_411_784
    ),
    CalculatorUnit(
      id: "byte",
      dimension: .data,
      symbol: "B",
      aliases: ["byte", "bytes"],
      scaleToBase: 1
    ),
    CalculatorUnit(
      id: "bit",
      dimension: .data,
      symbol: "bit",
      aliases: ["bit", "bits"],
      scaleToBase: 0.125
    ),
    CalculatorUnit(
      id: "kilobyte",
      dimension: .data,
      symbol: "kB",
      aliases: ["kb", "kilobyte", "kilobytes"],
      scaleToBase: 1_000
    ),
    CalculatorUnit(
      id: "megabyte",
      dimension: .data,
      symbol: "MB",
      aliases: ["mb", "megabyte", "megabytes"],
      scaleToBase: 1_000_000
    ),
    CalculatorUnit(
      id: "gigabyte",
      dimension: .data,
      symbol: "GB",
      aliases: ["gb", "gigabyte", "gigabytes"],
      scaleToBase: 1_000_000_000
    ),
    CalculatorUnit(
      id: "terabyte",
      dimension: .data,
      symbol: "TB",
      aliases: ["tb", "terabyte", "terabytes"],
      scaleToBase: 1_000_000_000_000
    ),
    CalculatorUnit(
      id: "kibibyte",
      dimension: .data,
      symbol: "KiB",
      aliases: ["kib", "kibibyte", "kibibytes"],
      scaleToBase: 1_024
    ),
    CalculatorUnit(
      id: "mebibyte",
      dimension: .data,
      symbol: "MiB",
      aliases: ["mib", "mebibyte", "mebibytes"],
      scaleToBase: 1_048_576
    ),
    CalculatorUnit(
      id: "gibibyte",
      dimension: .data,
      symbol: "GiB",
      aliases: ["gib", "gibibyte", "gibibytes"],
      scaleToBase: 1_073_741_824
    ),
    CalculatorUnit(
      id: "tebibyte",
      dimension: .data,
      symbol: "TiB",
      aliases: ["tib", "tebibyte", "tebibytes"],
      scaleToBase: 1_099_511_627_776
    ),
  ]

  static func defaultTarget(for unit: CalculatorUnit) -> CalculatorUnit? {
    guard let targetID = defaultTargetIDs[unit.id] else {
      return nil
    }
    return units.first { $0.id == targetID }
  }

  static func unit(named name: String) -> CalculatorUnit? {
    unitsByAlias[name.lowercased()]
  }
}

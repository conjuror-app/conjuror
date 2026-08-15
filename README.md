# Conjuror

Conjuror is a keyboard-first macOS application launcher. Press `⌥ Space` to
show or hide its single Dockless window, type to rank installed applications,
use the arrow keys to select, and press Return to open. Type `>` to switch to
Apple Shortcuts, then search and press Return or click a result to run it. Type
`:` to open the emoji grid, search by Unicode name (including gender and skin
tone), and press Return to copy. Recently copied emoji appear first when the
emoji search is empty. Its menu bar item provides access to Settings and Quit.

In application mode, Conjuror also evaluates calculations while you
type. Calculator answers appear above matching applications; selecting one and
pressing Return or clicking it copies the compact result and hides the launcher.
Plain numbers and incomplete expressions remain regular application searches.

Supported calculator syntax includes arithmetic and parentheses, powers,
percentages, `mod`, `pi`, `e`, `sqrt`, `abs`, implicit multiplication, and word
operators such as `plus`, `minus`, `times`, `divided by`, and `over`. Examples:
`2 plus 3 times 4`, `100 + 15%`, `20% of 50`, and `2pi`. Chained percentage
changes compound against each intermediate result, so `123 + 25% + 10%` is
`169.125`. Group percentages to apply them to the same source value:
`123 + (25% + 10%)` is `166.05`.

Integer conversion supports decimal, hexadecimal, octal, and binary with
`decimal`/`dec`, `hexadecimal`/`hex`, `octal`/`oct`, and `binary`/`bin` names.
Use `to`, `in`, `->`, or `→`, for example `255 to hex` or `0o377 to binary`.
Hexadecimal, octal, and binary results use `0x`, `0o`, and `0b` prefixes.
Entering a prefixed integer such as `0xFF` converts it directly to decimal.
Negative values place the sign before the prefix, such as `-0x2A`.

Quantity calculations support length, mass, duration, temperature, volume, and
decimal or binary data units. A bare quantity automatically converts to a
sensible counterpart, such as `100 lbs` to kilograms, `1 cm` to inches, or
`1 mile` to kilometers. Use `to`, `in`, `->`, or `→` to choose an explicit
target, combine compatible units with `+` or `-`, or type composite quantities.
Examples: `10 km to miles`, `10kg + 500g`, `30 °C to °F`, and `5 ft 3 in`. US
customary volume units use US definitions.

Relative dates support `N minutes/hours/days/weeks/months/years from now` and
`N minutes/hours/days/weeks/months/years ago`, and include both the resulting
local date and time. Minutes, hours, days, and weeks may be decimal values;
months and years must be whole numbers. Examples: `5 days from now`, `1.5 hours
from now`, and `2 weeks ago`.

Timezone conversion supports timezone abbreviations recognized by macOS and
12- or 24-hour clock times. Use `to`, `in`, `->`, or `→`, for example `10:00
BST in EST` or `9am GMT → PDT`. Explicit standard and daylight abbreviations
use their stated fixed offsets, so pairs such as `EST`/`EDT`, `CET`/`CEST`, and
`NZST`/`NZDT` remain distinct; other macOS abbreviations use their current
offset. A time with just a source abbreviation, such as `12:00 PST`, converts
to the Mac's current timezone. When the source abbreviation is omitted, as in
`1:00 pm in PDT`, the Mac's current timezone is used with its daylight-saving
rules for the current date.
Optional currency conversion supports ISO codes and common symbols, for example
`100 USD to EUR`, `$50 in GBP`, and `20 EUR → ¥`. A bare amount such as `1 CAD`
converts to the currency from the user's regional settings. It is disabled by default.
When enabled in Settings, Conjuror downloads a complete exchange-rate snapshot
from [Frankfurter](https://frankfurter.dev) once per day; search text is never
sent. The latest snapshot remains available offline, and disabling the feature
deletes its cached rates.

The app targets macOS 14 and scans `/Applications`, `/System/Applications`,
`/System/Applications/Utilities`, `~/Applications`, and application folders on
mounted volumes without external packages. Shortcuts that require input are
currently excluded. macOS asks for Automation permission the first time
Conjuror accesses Shortcuts Events. Launch at login is off by default and can
be enabled in General Settings. If macOS requires approval, Conjuror links to
the Login Items pane in System Settings.

## Development

The project enables complete Swift concurrency checking in Debug and Release
builds.

### Calculator evaluator precedence

Calculator input is evaluated in this order: relative date, timezone, currency,
radix, quantity, then arithmetic. This order is part of the calculator grammar:
specialized evaluators must reject input they do not fully recognize so that a
later evaluator can handle it. Preserve the order when adding syntax and add a
precedence test for expressions accepted by more than one evaluator.

Build the app or run its tests with Make:

```sh
make build
make test
```

Build artifacts are written to `.derivedData`. Run `make clean` to remove them.
Regenerate the checked-in Unicode emoji catalog with `make generate-emoji`.

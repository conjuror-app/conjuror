# Conjuror

Conjuror is a keyboard-first macOS application launcher. Press `⌥ Space` to
show or hide its single Dockless window, type to rank installed applications,
use the arrow keys to select, and press Return to open. Type `>` to switch to
Apple Shortcuts, then search and press Return or click a result to run it. Its
menu bar item provides access to Settings and Quit.

In application mode, Conjuror also evaluates calculations while you
type. Calculator answers appear above matching applications; selecting one and
pressing Return or clicking it copies the compact result and hides the launcher.
Plain numbers and incomplete expressions remain regular application searches.

Supported calculator syntax includes arithmetic and parentheses, powers,
percentages, `mod`, `pi`, `e`, `sqrt`, `abs`, implicit multiplication, and word
operators such as `plus`, `minus`, `times`, `divided by`, and `over`. Examples:
`2 plus 3 times 4`, `100 + 15%`, `20% of 50`, and `2pi`.

Quantity calculations support length, mass, duration, temperature, volume, and
decimal or binary data units. A bare quantity automatically converts to a
sensible counterpart, such as `100 lbs` to kilograms, `1 cm` to inches, or
`1 mile` to kilometers. Use `to`, `in`, `->`, or `→` to choose an explicit
target, combine compatible units with `+` or `-`, or type composite quantities.
Examples: `10 km to miles`, `10kg + 500g`, `30 °C to °F`, and `5 ft 3 in`. US
customary volume units use US definitions.

Timezone conversion supports timezone abbreviations recognized by macOS and
12- or 24-hour clock times. Use `to`, `in`, `->`, or `→`, for example `10:00
BST in EST` or `9am GMT → PDT`. Explicit standard and daylight abbreviations
use their stated fixed offsets, so pairs such as `EST`/`EDT`, `CET`/`CEST`, and
`NZST`/`NZDT` remain distinct; other macOS abbreviations use their current
offset. When the source abbreviation is
omitted, as in `1:00 pm in PDT`, the Mac's current timezone is used with its
daylight-saving rules for the current date.

The app targets macOS 14 and scans `/Applications`, `/System/Applications`,
`/System/Applications/Utilities`, `~/Applications`, and application folders on
mounted volumes without external packages. Shortcuts that require input are
currently excluded. macOS asks for Automation permission the first time
Conjuror accesses Shortcuts Events.

## Development

The project enables complete Swift concurrency checking in Debug and Release
builds.

Build the app or run its tests with Make:

```sh
make build
make test
```

Build artifacts are written to `.derivedData`. Run `make clean` to remove them.

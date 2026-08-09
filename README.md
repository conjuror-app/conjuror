# Conjuror

Conjuror is a keyboard-first macOS application launcher. Press `⌥ Space` to
show or hide its single Dockless window, type to rank installed applications,
use the arrow keys to select, and press Return to open. Type `>` to switch to
Apple Shortcuts, then search and press Return or click a result to run it. Its
menu bar item provides quick access to the launcher, Settings, and Quit.

In application mode, Conjuror also evaluates scalar calculations while you
type. Calculator answers appear above matching applications; selecting one and
pressing Return or clicking it copies the compact result and hides the launcher.
Plain numbers and incomplete expressions remain regular application searches.

Supported calculator syntax includes arithmetic and parentheses, powers,
percentages, `mod`, `pi`, `e`, `sqrt`, `abs`, implicit multiplication, and word
operators such as `plus`, `minus`, `times`, `divided by`, and `over`. Examples:
`2 plus 3 times 4`, `100 + 15%`, `20% of 50`, and `2pi`.

The app targets macOS 14 and scans `/Applications`, `/System/Applications`,
`/System/Applications/Utilities`, `~/Applications`, and application folders on
mounted volumes without external packages. Shortcuts that require input are
currently excluded. macOS asks for Automation permission the first time
Conjuror accesses Shortcuts Events.

## Development

The project enables complete Swift concurrency checking in Debug and Release
builds.

```sh
xcodebuild test \
  -project Conjuror.xcodeproj \
  -scheme Conjuror \
  -derivedDataPath .derivedData
```

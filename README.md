# Conjuror

Conjuror is a keyboard-first macOS application launcher. Press `⌥ Space` to
show or hide its single Dockless window, type to rank installed applications,
use the arrow keys to select, and press Return to open.

The app targets macOS 14 and scans `/Applications`, `/System/Applications`,
`/System/Applications/Utilities`, and `~/Applications` without external
packages.

## Development

```sh
xcodebuild test \
  -project Conjuror.xcodeproj \
  -scheme Conjuror \
  -derivedDataPath .derivedData

./script/build_and_run.sh --verify
```

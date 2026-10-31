# Conjuror

Conjuror is a macOS launcher for opening apps and files, running Apple Shortcuts,
copying emoji, and doing calculations and conversions.

## Installation

Building from source requires macOS 26 or later and Xcode.

```sh
git clone https://github.com/conjuror-app/conjuror.git
cd conjuror
make build
open .derivedData/Build/Products/Debug/Conjuror.app
```

Copy `Conjuror.app` from `.derivedData/Build/Products/Debug` into `/Applications`
to install it. You can enable launch at login in General Settings.

## Usage

Press `⌥ Space` to show or hide Conjuror. Type to search, use the arrow keys to select
a result, then press Return or click to use it. Press `⌘ Return` to reveal the selected
app or file in Finder. Open Settings or quit from the menu bar item.

### Applications and calculations

Type an app's name to find and open it. Calculations appear above matching apps.
Select a calculation result to copy it and close the launcher.

- Arithmetic: `2 plus 3 times 4`, `100 + 15%`, `20% of 50`, `2pi`.
- Number bases: `255 to hex`, `0o377 to binary`.
- Units: `10 km to miles`, `10kg + 500g`, `30 °C to °F`, `5 ft 3 in`.
- Relative dates: `5 days from now`, `2 weeks ago`, `now + 90 seconds`, `now - 3 months`.
- Dates: `now - 1 aug 2025 in days`, `today - 1 jan 1990 in years`, `1 aug 2025 + 30 days`.
- Timezones: `10:00 BST in EST`, `9am GMT → PDT`.
- Currency: `100 USD to EUR`, `$50 in GBP`.

Use `to`, `in`, `->`, or `→` for conversions. Currency conversion is off by default.
Enable it in Settings to download daily exchange rates from
[Frankfurter](https://frankfurter.dev). Conjuror never sends your search text.
Cached rates work offline; turning currency conversion off deletes the cache.

### Apple Shortcuts

Type `>` to search your shortcuts, then select one to run it. Conjuror excludes
shortcuts that require input. macOS may ask for Automation permission on first use.

### Emoji

Type `:` to search emoji by name, gender, or skin tone. Press Return to copy the
selected emoji. Recent emoji appear first when the search is empty.

### Files and folders

Type `/` to search files and folders by name using Spotlight. Press Return to open
the selected item. On first use, Conjuror requests access to Desktop, Documents,
Downloads, and iCloud Drive. You can also grant access in Settings.

# Conjuror

Conjuror is a keyboard-first application launcher for macOS. It provides one fast,
Dockless interface for opening applications, running Apple Shortcuts, finding emoji,
and performing everyday calculations and conversions.

Conjuror exists to keep common tasks close to the keyboard. Instead of moving between
a launcher, calculator, emoji picker, and conversion tools—or sending queries to a
remote service—it ranks and evaluates input locally in a small native app. Network
access is optional and used only to update currency exchange rates.

## Installation

Conjuror currently builds from source and requires macOS 26 or later and a compatible
version of Xcode.

```sh
git clone https://github.com/conjuror-app/conjuror.git
cd conjuror
make build
open .derivedData/Build/Products/Debug/Conjuror.app
```

To install it permanently, copy `Conjuror.app` from
`.derivedData/Build/Products/Debug` into `/Applications`.

The first time Conjuror accesses Apple Shortcuts, macOS may request Automation
permission. Launch at login is disabled by default and can be enabled in General
Settings.

## Usage

Press `⌥ Space` to show or hide Conjuror. Type to search, use the arrow keys to change
the selection, and press Return—or click a result—to perform the selected action.
The menu bar item provides access to Settings and Quit.

### Applications and calculations

Search normally to rank installed applications. Conjuror scans standard application
folders, including mounted volumes. In the same mode, it recognizes calculations and
places their results above matching applications. Selecting a result copies it and
hides the launcher; plain numbers and incomplete expressions remain regular searches.

Supported input includes:

- Arithmetic, parentheses, powers, percentages, `mod`, `pi`, `e`, `sqrt`, `abs`, and
  implicit multiplication: `2 plus 3 times 4`, `100 + 15%`, `20% of 50`, `2pi`.
- Decimal, hexadecimal, octal, and binary conversion: `255 to hex`, `0o377 to binary`,
  or simply `0xFF`.
- Length, mass, duration, temperature, volume, and data units: `10 km to miles`,
  `10kg + 500g`, `30 °C to °F`, `5 ft 3 in`.
- Relative dates: `5 days from now`, `1.5 hours from now`, `2 weeks ago`.
- Timezones: `10:00 BST in EST`, `9am GMT → PDT`, `12:00 PST`.
- Optional currency conversion: `100 USD to EUR`, `$50 in GBP`, `20 EUR → ¥`.

Use `to`, `in`, `->`, or `→` for explicit conversions. Bare quantities and currency
amounts convert to a sensible counterpart or the currency from your regional settings.
Currency conversion is disabled by default; when enabled, Conjuror downloads a daily
exchange-rate snapshot from [Frankfurter](https://frankfurter.dev). Search text is
never sent, cached rates work offline, and disabling the feature deletes the cache.

### Apple Shortcuts

Type `>` to enter Shortcuts mode, search, then press Return or click a result to run
it. Shortcuts that require input are currently excluded.

### Emoji

Type `:` to open the emoji grid. Search by Unicode name, including gender and skin
tone, then press Return to copy the selection. Recently copied emoji appear first
when the search is empty.

### Files and folders

Type `/` to search Spotlight-indexed files and folders by name, then press Return to
open the selected item. Search stays on-device and normal macOS privacy permissions
still apply. Conjuror requests access to Desktop, Documents, Downloads, and iCloud
Drive the first time file search runs; access can also be requested from Settings.

## Development

Build and test with Make:

```sh
make build
make test
```

Other useful commands are:

```sh
make format          # Format Swift sources
make lint            # Check Swift formatting
make generate-emoji  # Regenerate the checked-in Unicode emoji catalog
make clean            # Remove build output
```

Build artifacts are written to `.derivedData`. Emoji generation requires Node.js; the
version used by the project is declared in `.mise.toml`. The project enables complete
Swift concurrency checking in Debug and Release builds.

### Direct distribution

The Xcode archive, Developer ID notarization upload, and final app export can be run
from the command line:

```sh
make archive
make notarize
```

These targets mirror Xcode's Custom → Direct Distribution workflow. They require an
Apple Developer account configured in Xcode, access to a Developer ID Application
certificate, and a `notarytool` Keychain profile named `conjuror-notary`. Create the
profile once with:

```sh
xcrun notarytool store-credentials conjuror-notary \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "Y54Z78V9M7" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

`make notarize` exports the app, submits it to Apple, waits for notarization, and then
staples and validates the ticket. The finished app is written to
`.derivedData/Export/Conjuror.app`. A different Keychain profile can be selected with
`make notarize NOTARY_PROFILE=profile-name`.

Run `make zip` afterward to validate and package the notarized app as
`builds/conjuror-<marketing-version>-<build-version>.zip`. The `builds` directory is
ignored by source control.

### Calculator evaluator precedence

Calculator input is evaluated in this order: relative date, timezone, currency, radix,
quantity, then arithmetic. This order is part of the calculator grammar: specialized
evaluators must reject input they do not fully recognize so a later evaluator can
handle it. Preserve the order when adding syntax, and add a precedence test for
expressions accepted by more than one evaluator.

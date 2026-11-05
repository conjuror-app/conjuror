# Conjuror

Conjuror is a macOS launcher for opening apps, files, and links, managing running
apps, running Apple Shortcuts and system commands, copying emoji, and doing
calculations and conversions.

## Installation

Download the app ZIP from [GitHub Releases](https://github.com/conjuror-app/conjuror/releases),
unzip it, and move `Conjuror.app` into `/Applications`. Requires macOS 26 or later.
The `.dSYM.zip` files are debug symbols and are not needed to run the app.

Alternatively, install the alpha with Homebrew:

```fish
brew install --cask conjuror-app/tap/conjuror@alpha
```

### Building from source

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

Type an app's name to find and open it. Use Settings → Apps → Excluded apps to hide
individual installations from search and recent results. Remove an exclusion to show
the app again. Exclusions use the app's path, so moving an app requires excluding it again.

Give an app an alias or a hotkey in Settings → Apps → Aliases & Hotkeys. Typing an
alias, such as `vs` for Visual Studio Code, ranks that app first, and typing the start
of an alias also finds it. Each app's alias appears beside it in results. A hotkey
opens or switches to the app without showing Conjuror, and hides the app if it's
already in front. An alias does nothing while its app is excluded, but its hotkey still
works. Aliases and hotkeys follow an app that moves, as long as only one copy is
installed.

Calculations appear above matching apps.
Select a calculation result to copy it and close the launcher.

- Arithmetic: `2 plus 3 times 4`, `100 + 15%`, `20% of 50`, `2pi`.
- Number bases: `255 to hex`, `0o377 to binary`.
- Units: `10 km to miles`, `10kg + 500g`, `30 °C to °F`, `5 ft 3 in`.
- Relative dates: `5 days from now`, `2 weeks ago`, `now + 90 seconds`, `now - 3 months`.
- Dates: `now - 1 aug 2025 in days`, `today - 1 jan 1990 in years`, `1 aug 2025 + 30 days`.
- Timezones: `10:00 BST in EST`, `9am GMT → PDT`.
- Currency: `100 USD to EUR`, `$50 in GBP`, `500*21 in GBP in USD`.

Use `to`, `in`, `->`, or `→` for conversions. Currency conversion is off by default.
Enable it in Settings to download daily exchange rates from
[Frankfurter](https://frankfurter.dev). Conjuror never sends your search text.
Cached rates work offline; turning currency conversion off deletes the cache.

### Quicklinks and web search

Quicklinks open saved URLs from the launcher. Type a quicklink's keyword followed by
search text, such as `gh swift testing`, to search GitHub for "swift testing". Typing
part of a quicklink's name also finds it, listed after matching apps. Pressing Return on
a keyword with no search text fills in the keyword so you can keep typing.

The last row searches the web for whatever you typed. Press `⌥ Return` to choose it
from any row. Choose the search engine, or turn the row off, in Settings → Quicklinks.

Conjuror comes with Google (`g`), DuckDuckGo (`ddg`), GitHub (`gh`), and Wikipedia
(`wiki`). Add, edit, or remove quicklinks in Settings → Quicklinks. Put `{query}` in a
URL where the search text goes, as in `https://kagi.com/search?q={query}`. A URL
without `{query}` opens as it is. Each quicklink opens in the default app for its URL
or in an app you choose. "Restore Built-ins" adds back any built-in you removed.

Search text is only sent to a site when you open one of its quicklinks.

### Apple Shortcuts

Type `>` to search your shortcuts, then select one to run it. Conjuror excludes
shortcuts that require input. macOS may ask for Automation permission on first use.

### System commands

Type a command's name, such as `lock`, `sleep`, or `empty trash`, to find it among
your apps. Type `!` to list every command. The commands are Lock Screen, Sleep,
Sleep Displays, Start Screen Saver, Show Desktop, Toggle Dark Mode, Eject All Disks,
Empty Trash, Log Out, Restart, and Shut Down.

Empty Trash and Eject All Disks ask you to press Return again to confirm; press Escape
to cancel. Log Out, Restart, and Shut Down show the macOS confirmation dialog.
macOS may ask for Automation permission the first time you empty the Trash (Finder)
or toggle dark mode (System Events). Turn system commands off in Settings → Apps.

### Emoji

Type `:` to search emoji by name, gender, or skin tone. Press Return to copy the
selected emoji. Recent emoji appear first when the search is empty.

### Files and folders

Type `/` to search files and folders by name using Spotlight. Press Return to open
the selected item. On first use, Conjuror requests access to Desktop, Documents,
Downloads, and iCloud Drive. You can also grant access in Settings.

### Running apps

Type `@` to list running apps, then press Return to switch to the selected one.
Apps excluded in Settings do not appear.

| Key | Action |
| --- | --- |
| `⌘ H` | Hide the app |
| `⌥ ⌘ H` | Hide other apps and switch to this one |
| `⌘ ⌫` | Quit the app |
| `⌥ ⌘ ⌫` | Force quit the app |
| `⌘ R` | Quit and reopen the app |
| `⇧ ⌘ ⌫` | Quit every listed app except Finder |
| `⌘ Return` | Reveal the app in Finder |

Force quit and quitting all listed apps ask for confirmation. Press Return to
confirm or Escape to cancel.

## Feedback

Report bugs and suggest changes in [Issues](https://github.com/conjuror-app/conjuror/issues).

## Publishing releases

See [the release instructions](docs/releases.md) for signing, notarizing, and
publishing a release from this repository.

## Licence

Conjuror is licensed under the [BSD 3-Clause License](LICENSE).

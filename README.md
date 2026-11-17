# Conjuror

Conjuror is a keyboard launcher for macOS. Press a hotkey, type a few letters, and
press Return. It opens apps, files, and links, switches between running apps, runs
Apple Shortcuts and system commands, copies emoji, and does sums and unit
conversions without opening another app.

It's still alpha software, so expect rough edges.

## Installation

Conjuror needs macOS 26 or later.

Download the latest ZIP from [GitHub Releases](https://github.com/conjuror-app/conjuror/releases),
unzip it, and move `Conjuror.app` into `/Applications`. You can ignore the `.dSYM.zip`
files. They hold debug symbols and the app runs without them.

Or install the alpha with Homebrew:

```fish
brew install --cask conjuror-app/tap/conjuror@alpha
```

Conjuror lives in the menu bar and has no Dock icon. To start it when you log in,
turn on Launch at login in Settings → General.

### Building from source

You need macOS 26 or later and Xcode.

```fish
git clone https://github.com/conjuror-app/conjuror.git
cd conjuror
make build
open .derivedData/Build/Products/Debug/Conjuror.app
```

To install your build, copy `Conjuror.app` from `.derivedData/Build/Products/Debug`
into `/Applications`. Run `make test` to run the tests.

## Usage

Press `⌥ Space` to show or hide Conjuror. Type to search, pick a result with the arrow
keys, then press Return or click it. `⌘ Return` reveals the selected app or file in
Finder. The menu bar item has Settings and Quit.

A character at the start of the search switches mode:

| Prefix | Mode |
| --- | --- |
| none | Apps, System Settings, system commands, quicklinks, and calculations |
| `@` | Running apps |
| `>` | Apple Shortcuts |
| `:` | Emoji |
| `/` | Files and folders |
| `!` | System commands |

Shortcuts, emoji, and files also have their own hotkeys, which open Conjuror straight
into that mode. The defaults are `⌥⇧ Space` for Shortcuts, `⌥⇧ E` for emoji, and
`⌘⇧ F` for files. Change or turn them off in the matching Settings pane.

### Apps

Type part of an app's name to find it. Matching sections of System Settings, such as
Bluetooth or Displays, show up with your apps. Turn them off in Settings → Apps if you'd
rather not see them.

Settings → Apps → Aliases & Hotkeys lets you give an app an alias, a hotkey, or both.
Typing an alias, such as `vs` for Visual Studio Code, puts that app first. Typing the
start of an alias finds it too, and the alias shows next to the app in results. A hotkey
opens the app, or switches to it if it's already running. Press the hotkey again while
the app is in front and Conjuror hides it. You don't need to open the launcher for any
of this.

To hide an app from search and recent results, add it in Settings → Apps → Excluded.
Exclusions match the app's path, so if you move the app you'll need to exclude it again.
An excluded app's alias stops working, but its hotkey still works. Aliases and hotkeys
follow an app when it moves, as long as you only have one copy installed.

### Calculations

Calculations appear above matching apps. Select one to copy the result and close the
launcher.

- Arithmetic: `2 plus 3 times 4`, `100 + 15%`, `20% of 50`, `2pi`
- Number bases: `255 to hex`, `0o377 to binary`
- Units: `10 km to miles`, `10kg + 500g`, `30 °C to °F`, `5 ft 3 in`
- Relative dates: `5 days from now`, `2 weeks ago`, `now + 90 seconds`, `now - 3 months`
- Dates: `now - 1 aug 2025 in days`, `today - 1 jan 1990 in years`, `1 aug 2025 + 30 days`
- Timezones: `10:00 BST in EST`, `9am GMT → PDT`
- Currency: `100 USD to EUR`, `$50 in GBP`, `500*21 in GBP in USD`

Any of `to`, `in`, `->`, or `→` works for a conversion.

Currency conversion is off by default. Turn it on in Settings → Calculator and Conjuror
downloads daily exchange rates from [Frankfurter](https://frankfurter.dev). The request
only asks for rates. Your search text never leaves your Mac. Cached rates keep working
offline, and turning currency conversion off deletes the cache.

### Quicklinks and web search

A quicklink is a saved URL with an optional keyword. Type the keyword and some search
text, such as `gh swift testing`, to search GitHub for "swift testing". Typing part of a
quicklink's name also finds it, listed after matching apps. Press Return on a keyword
with nothing after it and Conjuror fills in the keyword so you can keep typing.

Conjuror ships with Google `g`, DuckDuckGo `ddg`, GitHub `gh`, and Wikipedia `wiki`.
Add, edit, or remove quicklinks in Settings → Quicklinks. Put `{query}` in the URL where
the search text should go, as in `https://kagi.com/search?q={query}`. A URL without
`{query}` opens as it is. Each quicklink opens in the default app for its URL unless you
pick a different one. Restore Built-ins brings back any of the four you deleted.

The last row in app results searches the web for whatever you typed. `⌥ Return` runs
that search from any row. Pick the search engine, or remove the row, in
Settings → Quicklinks.

Your search text only goes to a site when you open one of its quicklinks.

### Running apps

Type `@` to list running apps, then press Return to switch to one. Excluded apps don't
appear.

| Key | Action |
| --- | --- |
| `⌘ H` | Hide the app |
| `⌥ ⌘ H` | Hide other apps and switch to this one |
| `⌘ ⌫` | Quit the app |
| `⌥ ⌘ ⌫` | Force quit the app |
| `⌘ R` | Quit and reopen the app |
| `⇧ ⌘ ⌫` | Quit every listed app except Finder |
| `⌘ Return` | Reveal the app in Finder |

Force quit and quitting every app both ask first. Press Return to confirm or Escape to
cancel.

### Apple Shortcuts

Type `>` to search your shortcuts, then select one to run it. Shortcuts that need input
don't appear. macOS may ask for Automation permission the first time. Turn Shortcuts
mode off in Settings → Shortcuts.

### System commands

Type a command's name, such as `lock`, `sleep`, or `empty trash`, and it shows up with
your apps. Type `!` to list them all:

- Lock Screen
- Sleep
- Sleep Displays
- Start Screen Saver
- Show Desktop
- Toggle Dark Mode
- Eject All Disks
- Empty Trash
- Log Out
- Restart
- Shut Down

Empty Trash and Eject All Disks wait for a second Return before they run. Press Escape
to back out. Log Out, Restart, and Shut Down show the usual macOS confirmation dialog.

The first time you empty the Trash, macOS asks whether Conjuror can control Finder.
Toggling dark mode asks the same about System Events. Turn system commands off in
Settings → Apps.

### Emoji

Type `:` to search emoji by name, gender, or skin tone, then press Return to copy one.
With nothing typed, your recent emoji come first. Set a preferred skin tone in
Settings → Emoji and Conjuror applies it to every emoji that supports one. Turn emoji
mode off in the same pane.

### Files and folders

Type `/` to search files and folders by name. Results come from Spotlight, so anything
Spotlight doesn't index won't show up. Press Return to open the selected item.

The first time you search, Conjuror asks for access to Desktop, Documents, Downloads,
and iCloud Drive. You can also grant access, or turn file search
off, in Settings → Files.

### Appearance

Settings → General has a Minimal appearance with tighter spacing and smaller rows, an
accent colour for the launcher border and mode icons, and a limit on how many results
show before the list scrolls.

## Feedback

Report bugs and suggest changes in [Issues](https://github.com/conjuror-app/conjuror/issues).

## Publishing releases

[The release instructions](docs/releases.md) cover signing, notarizing, and publishing
a release from this repository.

## Licence

Conjuror is licensed under the [BSD 3-Clause License](LICENSE).

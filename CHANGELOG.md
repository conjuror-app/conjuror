# Changelog

## Unreleased

- Added ⌘Return to reveal the selected app or file in Finder.
- Added `now + 2 hours` and `now - 3 days` relative dates, and seconds as a relative date unit.

## 1.0 alpha (16)

- Restored focus to the previous app after copying an emoji or calculation result, or running a Shortcut.
- Restored focus to the previous app when closing the launcher with Escape or its hotkey.

## 1.0 alpha (15)

- Rendered the menu bar icon as a bolder monochrome symbol.
- Ranked multi-word and acronym file searches the same way as application search.
- Fixed a failed file open replacing file results with a search error.
- Restored file search and its error when reopening the launcher after a failed file open.

## 1.0 alpha (14)

- Showed separate installations of the same app in search with distinct names and preserved launch history.
- Refreshed application results when app folders change.
- Included executable apps such as Icon Composer in application search.
- Fixed scrolling to the selected file result when navigating with the keyboard.
- Ignored invalid saved hotkey values.
- Rejected relative date calculations with amounts too large to represent.

## 1.0 alpha (13)

- Added a Minimal launcher appearance with tighter spacing and smaller result rows.
- Fixed launcher resizing and hide/show transitions flickering as results change.
- Reduced Shortcuts icon memory by generating thumbnails in the catalog helper.
- Released the Settings window and SwiftUI view hierarchy when closed.
- Reduced typing allocations by reusing the application search index until its catalog changes.
- Released the decompressed emoji source text after parsing the catalog.

## 1.0 alpha (12)

- Reduced idle memory usage by loading emoji, Shortcuts, and application icons on demand.
- Reduced memory after hiding the launcher by releasing its window and SwiftUI view hierarchy.
- Reduced loaded Shortcuts memory by moving catalog extraction into a short-lived helper process.
- Reduced search memory usage by compacting application, Shortcut, and emoji indexes.
- Reduced search allocations by precomputing candidate acronyms.
- Removed action counts from Shortcut results.

## 1.0 alpha (11)

- Added iCloud Drive to protected folder access requests.
- Fixed broad fuzzy file searches continuing indefinitely.
- Fixed multi-word fuzzy file searches failing to match across filename words.
- Fixed single-word file searches crashing before Spotlight could start.

## 1.0 alpha (10)

- Added a dedicated Apps section in settings.
- Added an accent colour setting shared by the launcher border and mode icons.
- Added fuzzy file and folder name search.
- Added System Settings sections to application search.
- Fixed Keychain Access and Passwords missing from application search.
- Fixed the settings window reopening on a previously active macOS Space.

## 1.0 alpha (9)

- Added a setting to configure the launcher border.
- Added a setting to disable file and folder search.

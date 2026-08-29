# Changelog

## Unreleased

- Reduced idle memory usage by loading emoji, Shortcuts, and application icons on demand.
- Reduced loaded Shortcuts memory by moving catalog extraction into a short-lived helper process.
- Reduced search memory usage by compacting application, Shortcut, and emoji indexes.
- Reduced search allocations by precomputing candidate acronyms.

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

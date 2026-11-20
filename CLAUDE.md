# Focus Until: notes for Claude

A macOS menu bar app (Swift, AppKit + SwiftUI) that turns on Do Not Disturb for N minutes or until a clock time.
See README.md for what it does from the user's side.

## Layout

- `Sources/Parse.swift`: input parsing (`Parse.minutes`, `Parse.until`) and formatting (`Fmt`). Foundation only, no AppKit, so it can be unit-tested.
- `Sources/Focus.swift`: two pieces.
  - `Shortcut` runs `/usr/bin/shortcuts run "DND On"` or `"DND Off"`.
  - `FocusController` (an ObservableObject) holds `endDate`, saves it to UserDefaults, and has a 1s timer plus a wake-from-sleep check.
- `Sources/Panel.swift`: the SwiftUI popover. It has the For/Until picker, a live preview, confirmation over 1h30, and the launch-at-login checkbox.
- `Sources/main.swift`: three pieces, in this order.
  - The CLI flag `--launch-at-login on|off`.
  - The single-instance guard.
  - `AppDelegate`, which owns the status item and popover and handles reopen (Spotlight opens the panel).
- `Resources/`: Info.plist (`LSUIElement`, bundle id `local.focusuntil`) and AppIcon.icns.
- `shortcuts/`: plist sources for the two shortcuts. `install-shortcuts.sh` signs them and opens them for import.
  - Signed `.shortcut` files are gitignored. They embed a per-account Apple signing certificate, so never commit them.
- `Tests/main.swift`: a plain assert-style test runner for Parse and Fmt. It isn't XCTest, because only the Command Line Tools are installed, not Xcode.

## Commands

Run the parser tests (always after touching Parse.swift):
```bash
./test.sh
```

Build, then install to `~/Applications` and relaunch:
```bash
./build.sh install
```

There's no Xcode project. `build.sh` calls `swiftc` directly with `-swift-version 5`, targeting macOS 14.

## Behaviour rules (the user asked for these)

- **Until** means the *next* occurrence of that time. If it has already passed today, use tomorrow.
- An hour from 1 to 12 with no am/pm and no leading zero is ambiguous. Pick whichever of h and h+12 comes first.
  - `am`/`pm` makes it explicit.
  - A leading zero (`09:30`) means 24h.
  - 13–23 and 0 are always 24h.
- Ask for confirmation when the duration is **longer than 1h30** (more than 90 minutes).
- Keep it simple. It's meant to be a minimal tool: just the two modes, no presets or extra settings unless asked.

## Gotchas

- **There's no public API for Focus or Do Not Disturb.**
  - The toggle goes through the user's Shortcuts named exactly `DND On` and `DND Off`. If you rename them, update `Shortcut.on/off` too.
  - The current Do Not Disturb state can't be read: `~/Library/DoNotDisturb/DB` needs Full Disk Access. The app only trusts its own `endDate`.
- **Never build inside iCloud Drive.** It re-adds xattrs and codesign fails with "resource fork, Finder information, or similar detritus". That's why `build.sh` builds in `~/Library/Caches/FocusUntil-build`.
- **On quit, the app turns Do Not Disturb off** (`applicationWillTerminate` calls `stopBeforeQuit`).
  - The single-instance guard must quit with `exit(0)`, never `NSApp.terminate`. Otherwise the duplicate would turn off the running copy's session.
  - `pkill` sends SIGTERM, which skips that quit handler.
- **Launch at login** uses `SMAppService.mainApp`, which is tied to the installed bundle in `~/Applications`, not to this folder.
  - Only the app itself can register. The `--launch-at-login` flag exists so it can be done from a terminal.
  - The flag runs before the single-instance guard and exits right away.
- **The checkbox state** is read when the panel view is created. After changing it externally, restart the app.
- **Re-signing shortcuts** after editing their plist sources: run `./install-shortcuts.sh`.
  - `shortcuts sign` needs a network connection.
  - Importing needs the user to click "Add Shortcut". Running it again creates duplicates (e.g. "DND On 1") if the old ones still exist.
- **The repo is on GitHub.** Keep personal data out: no absolute `/Users/...` paths, no emails, and no signed shortcuts.

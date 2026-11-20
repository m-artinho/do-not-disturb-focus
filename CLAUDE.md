# Focus Until: notes for Claude

A macOS menu bar app (Swift, AppKit + SwiftUI) that turns on Do Not Disturb for N minutes or until a clock time.
See README.md for what it does from the user's side.

## Installing it for someone (playbook)

Follow this when a user asks to install, set up, update or uninstall the app. Nothing here needs `sudo`.
Don't change their global git config or anything outside the paths below.

### 1. Preflight: check, don't ask

- `sw_vers -productVersion` must be **14 or higher**. If it's lower, stop and tell the user it needs macOS Sonoma or later.
- `xcode-select -p` must succeed.
  - If it fails, the Command Line Tools are missing.
  - Ask the user to run `xcode-select --install` and finish the installer window. It's a GUI installer, so you can't complete it for them.
  - Wait until they confirm, then re-check.
- If the clone is inside iCloud Drive (the path contains `Mobile Documents`), suggest moving it somewhere like `~/dev`. Building still works, because output goes to `~/Library/Caches`, but iCloud tends to interfere with git.
- Check `shortcuts list` for exact lines `DND On` and `DND Off`. If either already exists, tell the user. It might be their own shortcut with the same name, and the app would run it.

### 2. Ask the user once

- **Launch at login?** Recommend yes. It's the only real choice in the install.
  - Use `AskUserQuestion` if it's available.
  - Ask it together with any warning about existing shortcuts.

### 3. Install

1. Run `./test.sh`. It should print `All tests passed`.
2. Before running `./install-shortcuts.sh`, tell the user:
   - The Shortcuts app will open once for each missing shortcut.
   - They need to click **Add Shortcut** each time.
   - They must keep the names unchanged.

   Then run it. Let the user click: adding a shortcut is their consent, so don't automate those dialogs.
   Wait for them to say they're done, then run the script again. It must report both as installed.
   - `shortcuts sign` needs a network connection and an Apple account signed in on the Mac.
   - If signing fails, tell the user how to create the shortcuts by hand: Shortcuts app › new shortcut › **Set Focus** action › Do Not Disturb › On, named `DND On`, and the same with Off, named `DND Off`.
3. Run `./build.sh install`. It builds, copies to `~/Applications/Focus Until.app`, and launches.
4. If the user wants launch at login:
   ```bash
   ~/Applications/"Focus Until.app"/Contents/MacOS/FocusUntil --launch-at-login on
   ```
   - It prints `enabled` when it worked.
   - `requiresApproval` means the user has to allow it in System Settings › General › Login Items.
   - Restart the app afterwards so the checkbox shows the new state: `pkill -x FocusUntil; open ~/Applications/"Focus Until.app"`.

### 4. Verify, because exit code 0 isn't proof

1. Run `shortcuts run "DND On"`.
   - The first run may show a macOS prompt asking to let the shortcut change Focus. The user has to allow it.
2. Ask the user to confirm that Do Not Disturb is on, for example in Control Center or by the moon in the menu bar.
3. Then run `shortcuts run "DND Off"`.

### 5. Hand-off

Tell the user:
- Click the moon-with-zzz icon in the menu bar, or press Cmd+Space and type "Focus Until".
- **For** takes minutes; **Until** takes a time.
- If the menu bar is crowded, the icon may be hidden behind the notch. Spotlight still opens the panel.

### Update

```bash
git pull && ./test.sh && ./build.sh install
```
- If files in `shortcuts/` changed, the user has to delete the old `DND On` and `DND Off` in the Shortcuts app first.
- Then run `./install-shortcuts.sh` again.

### Uninstall

The README "Uninstall" section has the steps. Run the `--launch-at-login off` command **before** deleting the app.

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
- `Tests/main.swift`: a plain assert-style test runner for Parse and Fmt. It isn't XCTest, so it runs with just the Command Line Tools and doesn't need Xcode.

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
  - Importing needs the user to click "Add Shortcut".
  - The script skips names that already exist. To pick up an edited plist, the user must delete the old shortcut first.
- **The repo is on GitHub.** Keep personal data out: no absolute `/Users/...` paths, no emails, and no signed shortcuts.

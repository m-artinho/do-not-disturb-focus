# Focus Until

A tiny macOS menu bar app that turns on **Do Not Disturb for N minutes** or **until a time**.
macOS itself only offers "for 1 hour" or "until I turn it off".

The menu bar icon is a moon with "zzz". It fills in and shows the time left (`25m`) while Do Not Disturb is on.

## Using it

- **Click the menu bar icon**, or press **Cmd+Space** and type **Focus Until**. Both open the panel.
- Pick **For** or **Until**, type a value, then press **Enter**.
- The line under the field shows what the app understood, for example `Until tomorrow 22:00 · 23h`.
- Anything longer than **1h30** asks you to confirm, in case of a typo.
- When it's on, the panel shows the end time and a **Turn off** button. Typing a new value changes the end time.
- **Launch at login** is the checkbox at the bottom of the panel.
- **Quit** also turns Do Not Disturb off, so it never stays on with nothing running to end it.

### What you can type

| Mode  | Examples |
|-------|----------|
| For   | `25`, `90`, `25m`, `1h30`, `2h` |
| Until | `14:30`, `23h`, `14h30`, `9.15`, `0930`, `2:30pm`, `2pm`, `9am`, `2:30 p.m.` |

How **Until** picks the time:
- It always uses the **next** time that matches. At 23:00, `22h` means tomorrow at 22:00, which is 23 hours away.
- An hour from 1 to 12 with no am/pm (`2:30`) could mean 02:30 or 14:30, so it uses **whichever comes first**.
- `am`/`pm` or a leading zero (`02:30`, `09:30`) makes the time exact.

## How it works

macOS has no public API for controlling Focus or Do Not Disturb, so the app runs two Shortcuts:

- `DND On`: Set Focus › Do Not Disturb › On
- `DND Off`: Set Focus › Do Not Disturb › Off

Their sources are the plist files in `shortcuts/`. Sign and import them with:
```bash
./install-shortcuts.sh
```
The Shortcuts app asks you to click **Add Shortcut** for each one. **The names must match exactly.**
Signed `.shortcut` files aren't committed, because they embed a signing certificate tied to the signer's Apple account.

Alternatively, create them by hand in the Shortcuts app: add a **Set Focus** action, set it to Do Not Disturb, and turn it On (or Off).

The app saves the end time and checks it once a second against the real clock, and again when the Mac wakes from sleep. When the time has passed, it runs `DND Off`. The end time survives an app restart, so the login item picks up where it left off.

## Building and installing

You need the Xcode Command Line Tools (`swiftc`, run `xcode-select --install` to get them) and macOS 14 or later. No Xcode project is needed.

Run the parser tests:
```bash
./test.sh
```

Build, copy to `~/Applications` and relaunch:
```bash
./build.sh install
```

`build.sh` builds in `~/Library/Caches/FocusUntil-build` and does an ad-hoc code signature. The installed app lives in `~/Applications/Focus Until.app`. It doesn't depend on where this project folder is, so you can move the folder freely.

Turn launch at login on or off from a terminal:
```bash
~/Applications/"Focus Until.app"/Contents/MacOS/FocusUntil --launch-at-login on
```

## Troubleshooting

- **The panel says a shortcut failed.** Check that the Shortcuts app has `DND On` and `DND Off` with those exact names. Run `./install-shortcuts.sh` again if needed.
- **Two icons in the menu bar.** That shouldn't happen anymore: a second copy hands over to the running one and quits. If it does, run `pkill -x FocusUntil`, then open the app again.
- **You turned Do Not Disturb off from Control Center.** The app can't see that and keeps counting down. At the end it just runs "off" again, which does no harm.

# Focus Until

A tiny macOS menu bar app that turns on **Do Not Disturb for N minutes** or **until a time**.
macOS itself only offers "for 1 hour" or "until I turn it off".

The menu bar icon is a moon with "zzz". It fills in and shows the time left (`25m`) while Do Not Disturb is on.

- No network access, no tracking.
- Everything stays on your Mac. The app only runs two Shortcuts that turn Do Not Disturb on and off.

## Install

You need **macOS 14 (Sonoma) or later**. There's no download: you build it from source in about a minute, so macOS doesn't show an "unidentified developer" warning.

### Option A: ask Claude Code

Open [Claude Code](https://claude.com/claude-code) in a folder where you keep projects and say:

> Clone https://github.com/m-artinho/do-not-disturb-focus and install it for me.

The repo's [`CLAUDE.md`](CLAUDE.md) gives Claude the full install steps: what to check, what to ask you, and how to verify it works.
You'll still need to click **Add Shortcut** twice in the Shortcuts app, because macOS requires a human for that.

### Option B: by hand

1. **Command Line Tools** provide the Swift compiler. No full Xcode is needed. Check whether you have them:
   ```bash
   xcode-select -p
   ```
   If that prints an error, install them and wait for the installer window to finish:
   ```bash
   xcode-select --install
   ```

2. **Get the code:**
   ```bash
   git clone https://github.com/m-artinho/do-not-disturb-focus.git
   ```
   ```bash
   cd do-not-disturb-focus
   ```

3. **Add the two Shortcuts** the app uses to control Do Not Disturb:
   ```bash
   ./install-shortcuts.sh
   ```
   - The Shortcuts app opens twice. Click **Add Shortcut** each time.
   - Run the script again to confirm. It should say both are installed.
   - Keep the names exactly **DND On** and **DND Off**.

4. **Build and install the app.** This puts it in `~/Applications` and starts it:
   ```bash
   ./build.sh install
   ```

5. **Optional: start it at login.** Tick **Launch at login** at the bottom of the panel, or run:
   ```bash
   ~/Applications/"Focus Until.app"/Contents/MacOS/FocusUntil --launch-at-login on
   ```

6. **Try it:** click the moon icon, choose **For**, type `1` and press Enter.
   - Do Not Disturb should turn on (check Control Center).
   - It should turn off again after a minute.

## Using it

- **Click the menu bar icon**, or press **Cmd+Space** and type **Focus Until**. Both open the panel.
- Pick **For** or **Until**, type a value, then press **Enter**.
- The line under the field shows what the app understood, for example `Until tomorrow 22:00 · 23h`.
- Anything longer than **1h30** asks you to confirm, in case of a typo.
- When it's on, the panel shows the end time and a **Turn off** button. Typing a new value changes the end time.
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

Their sources are the plist files in `shortcuts/`. `install-shortcuts.sh` signs them with your Apple account and opens them for import.
Signed `.shortcut` files aren't committed, because they embed a signing certificate tied to the signer's account.
You can also create them by hand in the Shortcuts app: add a **Set Focus** action, set it to Do Not Disturb, and turn it On (or Off).

The app saves the end time and checks it once a second against the real clock, and again when the Mac wakes from sleep. When the time has passed, it runs `DND Off`. The end time survives an app restart, so the login item picks up where it left off.

## Development

Run the parser tests:
```bash
./test.sh
```

Rebuild, reinstall and relaunch:
```bash
./build.sh install
```

- `build.sh` builds in `~/Library/Caches/FocusUntil-build` and does an ad-hoc code signature.
- The installed app is `~/Applications/Focus Until.app`. It doesn't depend on where this folder is.
- Don't keep the project in iCloud Drive: iCloud adds file metadata that breaks code signing.
- See [`CLAUDE.md`](CLAUDE.md) for architecture notes.

## Uninstall

1. Turn off launch at login. This only works while the app is still installed:
   ```bash
   ~/Applications/"Focus Until.app"/Contents/MacOS/FocusUntil --launch-at-login off
   ```
2. Quit it: click the menu bar icon, then **Quit**.
3. Remove the app, its build cache and its settings:
   ```bash
   rm -rf ~/Applications/"Focus Until.app" ~/Library/Caches/FocusUntil-build
   ```
   ```bash
   defaults delete local.focusuntil
   ```
4. In the Shortcuts app, delete **DND On** and **DND Off**.

## Troubleshooting

- **The panel says a shortcut failed.** Run `./install-shortcuts.sh`. It tells you which shortcut is missing. If you renamed one, change it back to `DND On` or `DND Off`.
- **"xcrun: error" or "swiftc: command not found".** The Command Line Tools are missing. Run `xcode-select --install`.
- **Two icons in the menu bar.** That shouldn't happen: a second copy hands over to the running one and quits. If it does, run `pkill -x FocusUntil`, then open the app again.
- **You turned Do Not Disturb off from Control Center.** The app can't see that and keeps counting down. At the end it just runs "off" again, which does no harm.

#!/bin/bash
# Signs the "DND On" / "DND Off" shortcuts from their plist sources and opens them
# for import. The Shortcuts app asks you to click "Add Shortcut" for each one.
# Signing needs a network connection (Apple signs them for your account).
set -euo pipefail
cd "$(dirname "$0")/shortcuts"
tmp="$(mktemp -d)"
for name in "DND On" "DND Off"; do
  plutil -convert binary1 "$name.plist" -o "$tmp/$name.unsigned.shortcut"
  shortcuts sign --mode anyone --input "$tmp/$name.unsigned.shortcut" --output "$name.shortcut"
  open "$name.shortcut"
  sleep 2
done
rm -rf "$tmp"
echo "Click \"Add Shortcut\" in each Shortcuts dialog. Names must stay exactly \"DND On\" and \"DND Off\"."

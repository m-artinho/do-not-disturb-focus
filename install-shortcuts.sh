#!/bin/bash
# Signs the "DND On" / "DND Off" shortcuts from their plist sources and opens them
# for import. The Shortcuts app asks you to click "Add Shortcut" for each one.
# Shortcuts that are already installed are skipped, so it's safe to run again.
# Signing needs a network connection (Apple signs them for your account).
set -euo pipefail
cd "$(dirname "$0")/shortcuts"

installed="$(shortcuts list)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
opened=0

for name in "DND On" "DND Off"; do
  if grep -qxF "$name" <<<"$installed"; then
    echo "✓ \"$name\" is already installed"
    continue
  fi
  plutil -convert binary1 "$name.plist" -o "$tmp/$name.unsigned.shortcut"
  shortcuts sign --mode anyone --input "$tmp/$name.unsigned.shortcut" --output "$name.shortcut"
  open "$name.shortcut"
  opened=$((opened + 1))
  sleep 2
done

if [ "$opened" -gt 0 ]; then
  echo "→ Click \"Add Shortcut\" in each Shortcuts dialog ($opened opened)."
  echo "  Keep the names exactly \"DND On\" and \"DND Off\". Run this script again to check."
else
  echo "All shortcuts are installed."
fi

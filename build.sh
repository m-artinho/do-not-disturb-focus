#!/bin/bash
# Builds "Focus Until.app". Pass "install" to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

# Build outside iCloud Drive: it re-adds xattrs that codesign rejects.
BUILD_DIR="$HOME/Library/Caches/FocusUntil-build"
APP="$BUILD_DIR/Focus Until.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
  Sources/*.swift -o "$APP/Contents/MacOS/FocusUntil"
cp Resources/Info.plist "$APP/Contents/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

xattr -cr "$APP" 
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "install" ]; then
  pkill -x FocusUntil 2>/dev/null && sleep 1 || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/"Focus Until.app"
  cp -R "$APP" ~/Applications/
  open ~/Applications/"Focus Until.app"
  echo "Installed to ~/Applications and launched"
fi

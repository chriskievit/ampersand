#!/bin/zsh
# Builds build/Ampersand.app from the SwiftPM executable and ad-hoc signs it.
set -euo pipefail
cd "${0:A:h}/.."
CONFIG="${1:-debug}"
swift build -c "$CONFIG" --product Ampersand
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Ampersand"
APP="build/Ampersand.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ampersand"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"

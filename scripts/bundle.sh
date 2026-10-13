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
# App icon: compile the Icon Composer document (Liquid Glass + legacy .icns fallback).
xcrun actool Resources/Ampersand.icon --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 26.0 --app-icon Ampersand \
    --output-partial-info-plist /dev/null >/dev/null
codesign --force --sign - "$APP"
echo "$APP"

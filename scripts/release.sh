#!/bin/zsh
# Builds a versioned Ampersand.app, as a DMG and a zip, for a GitHub release.
# Usage: scripts/release.sh <version>   (semantic-release passes the next version)
set -euo pipefail
cd "${0:A:h}/.."
VERSION="$1"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
APP="$(scripts/bundle.sh release | tail -1)"
# ditto keeps the bundle's extended attributes and signature intact; zip does not.
ditto -c -k --keepParent "$APP" "build/Ampersand-$VERSION.zip"
scripts/dmg.sh "$APP" "build/Ampersand-$VERSION.dmg"

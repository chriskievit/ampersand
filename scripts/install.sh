#!/bin/zsh
# Release build into /Applications so "Launch at login" points at a stable path.
set -euo pipefail
cd "${0:A:h}/.."
pkill -x Ampersand || true
APP="$(scripts/bundle.sh release | tail -1)"
rm -rf /Applications/Ampersand.app
cp -R "$APP" /Applications/Ampersand.app
echo "Installed /Applications/Ampersand.app"

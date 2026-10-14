#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
APP="$(scripts/bundle.sh "${1:-debug}" | tail -1)"
if [[ -n "${AMPERSAND_CONFIG_DIR:-}" ]]; then
  # Its own config: run a second copy next to the installed app and leave that one alone.
  # Only an earlier development copy is replaced; it stops its commands as it quits.
  pkill -f "$PWD/build/Ampersand.app/Contents/MacOS/Ampersand" || true
  open -n --env "AMPERSAND_CONFIG_DIR=$AMPERSAND_CONFIG_DIR" "$APP"
else
  pkill -x Ampersand || true
  open "$APP"
fi

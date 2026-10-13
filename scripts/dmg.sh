#!/bin/zsh
# Packs an app bundle into a drag-to-install DMG.
# Usage: scripts/dmg.sh <path/to/Ampersand.app> <output.dmg>
set -euo pipefail
cd "${0:A:h}/.."
APP="$1"
OUT="$2"
# dmgbuild writes the Finder layout directly, so it works on a headless CI runner.
VENV="build/.venv"
[[ -x "$VENV/bin/dmgbuild" ]] || { python3 -m venv "$VENV" && "$VENV/bin/pip" install -q dmgbuild; }
rm -f "$OUT"
"$VENV/bin/dmgbuild" -s scripts/dmg-settings.py -D app="$APP" Ampersand "$OUT" >/dev/null
echo "$OUT"

#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
pkill -x Ampersand || true
APP="$(scripts/bundle.sh "${1:-debug}" | tail -1)"
open "$APP"

#!/bin/bash
# Removes MTGO, its Whisky bottle, the launcher and the Desktop shortcut. Leaves Whisky installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/lib/common.sh"

read -r -p "Delete the '$BOTTLE' bottle (MTGO and its local data) and the launcher? [y/N] " a
[ "$a" = y ] || [ "$a" = Y ] || exit 0
if [ -x "$WINE_BIN/wineserver" ] && "$WHISKYCMD" list | grep -qE "^\| $BOTTLE +\|"; then
    bottle_env; wineserver -k 2>/dev/null || true
    "$WHISKYCMD" delete "$BOTTLE"
fi
rm -rf "$LAUNCHER_DIR" "$HOME/Desktop/MTGO.app"
ok "Removed. Uninstall Whisky with: brew uninstall --cask whisky"

#!/bin/bash
# Launches MTGO in the Whisky bottle via its ClickOnce shortcut, limited to a few CPU cores.
# Installed to ~/Library/Application Support/MTGO-Launcher/ by install.sh.
# MTGO_CPUS = hex CPU mask (default 3 = cores 0 and 1). Try 1 if it still freezes, f for 4 cores.
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"
bottle_env

mtgo_running && exit 0

# Start from a clean Wine session: a dfsvc.exe left over from an earlier launch would start MTGO
# without the CPU limit, and killing only dfsvc leaves stale COM state that breaks the shortcut.
wineserver -k 2>/dev/null; wineserver -w 2>/dev/null

cd "$DIR"
nohup wine64 affinity.exe "${MTGO_CPUS:-3}" "$APPREF_WIN" >"$DIR/launch.log" 2>&1 &

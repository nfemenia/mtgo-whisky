#!/bin/bash
# Launches MTGO in the Whisky bottle via its ClickOnce shortcut, limited to a few CPU cores.
# Installed to ~/Library/Application Support/MTGO-Launcher/ by install.sh.
# MTGO_CPUS = hex CPU mask (default 3 = cores 0 and 1). Try 1 if it still freezes, f for 4 cores.
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"
bottle_env

mtgo_running && exit 0

# A dfsvc.exe left over from an earlier launch would start MTGO without the CPU limit.
pkill -f 'dfsvc\.exe' 2>/dev/null; sleep 1

cd "$DIR"
nohup wine64 affinity.exe "${MTGO_CPUS:-3}" "$APPREF_WIN" >"$DIR/launch.log" 2>&1 &

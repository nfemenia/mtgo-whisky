# Shared settings and helpers for the MTGO-on-Whisky scripts. Source this, don't run it.

BOTTLE="${MTGO_BOTTLE:-MTGO}"
WHISKY_APP="/Applications/Whisky.app"
WHISKYCMD="$WHISKY_APP/Contents/Resources/WhiskyCmd"
WINE_BIN="$HOME/Library/Application Support/com.franke.Whisky/Libraries/Wine/bin"
LAUNCHER_DIR="$HOME/Library/Application Support/MTGO-Launcher"
MTGO_SETUP_URL="https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe"
# Note the space before ".appref-ms" - that is how the MTGO installer names it.
APPREF_WIN="C:\\users\\$USER\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Daybreak Game Company LLC\\Magic The Gathering Online .appref-ms"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Exports WINEPREFIX etc. for the bottle and puts Whisky's wine64 on PATH.
bottle_env() {
    eval "$("$WHISKYCMD" shellenv "$BOTTLE" | grep -v '^export PATH' | grep -v '^alias')"
    export PATH="$WINE_BIN:$PATH"
    export WINE=wine64
    [ -n "${WINEPREFIX:-}" ] || die "could not read the Wine prefix of bottle '$BOTTLE'"
}

appref_unix() {
    echo "$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Daybreak Game Company LLC/Magic The Gathering Online .appref-ms"
}

mtgo_running() { ps -eo command | grep -v grep | grep -qE '\\MTGO\.exe'; }

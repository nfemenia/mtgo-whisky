#!/bin/bash
# Installs Magic: The Gathering Online on an Apple Silicon Mac using Whisky (Wine), with every
# tweak needed to make it work. Safe to re-run: finished steps are detected and skipped.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/lib/common.sh"

# --- 1. Prerequisites --------------------------------------------------------------------------
log "Checking prerequisites"
[ "$(uname -s)" = Darwin ] || die "macOS only"
if [ "$(uname -m)" = arm64 ] && ! /usr/bin/pgrep -q oahd; then
    log "Installing Rosetta 2 (Wine runs MTGO as x86_64)"
    softwareupdate --install-rosetta --agree-to-license
fi
command -v brew >/dev/null || die "Homebrew is required: https://brew.sh"
ok "macOS $(sw_vers -productVersion) on $(uname -m)"

# --- 2. Whisky + winetricks --------------------------------------------------------------------
# frankea/whisky is the maintained fork of Whisky (the original is archived).
if [ ! -x "$WHISKYCMD" ]; then
    log "Installing Whisky"
    brew install --cask frankea/whisky/whisky
fi
command -v winetricks >/dev/null || { log "Installing winetricks"; brew install winetricks; }
ok "Whisky and winetricks installed"

# Whisky downloads its Wine build on first launch (GUI setup).
if [ ! -x "$WINE_BIN/wine64" ]; then
    log "Opening Whisky so it can download Wine - finish its setup window if it shows one"
    open "$WHISKY_APP"
    until [ -x "$WINE_BIN/wine64" ]; do sleep 5; done
fi
ok "Wine: $("$WINE_BIN/wine64" --version)"

# --- 3. Bottle ---------------------------------------------------------------------------------
if ! "$WHISKYCMD" list | grep -qE "^\| $BOTTLE +\|"; then
    log "Creating Whisky bottle '$BOTTLE'"
    "$WHISKYCMD" create "$BOTTLE"
fi
bottle_env
if [ ! -d "$WINEPREFIX/drive_c/windows" ]; then
    log "Initialising the Wine prefix"
    wine64 wineboot -u >/dev/null 2>&1
fi
ok "Bottle '$BOTTLE' at $WINEPREFIX"
mtgo_running && die "MTGO is running - close it first (the tweaks restart Wine)"

# --- 4. .NET 4.8 + fonts -----------------------------------------------------------------------
release=$(wine64 reg query 'HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full' /v Release 2>/dev/null \
          | awk '/Release/ {print $3}' | tr -d '\r')
if [ -z "$release" ] || [ $((release)) -lt 528040 ]; then
    log "Installing core fonts and .NET Framework 4.8 (this takes 10-20 minutes)"
    winetricks -q --force corefonts dotnet48
fi
wine64 winecfg -v win10 >/dev/null 2>&1
ok ".NET 4.8 installed, Windows version set to 10"

# --- 5. MTGO tweaks (from pauleve/docker-mtgo and our own debugging) ---------------------------
log "Applying MTGO tweaks"
wineserver -k 2>/dev/null || true
mkdir -p "$WINEPREFIX/drive_c/users/$USER/AppData/LocalLow"       # MTGO crashes if it is missing
wine64 reg add 'HKCU\Software\Wine\Drivers' /v Audio /t REG_SZ /d "" /f >/dev/null 2>&1   # no sound: avoids audio crashes
winetricks -q gdiplus=builtin winegstreamer=disabled >/dev/null 2>&1
wine64 reg add 'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1 /f >/dev/null 2>&1   # WPF software rendering
ok "Tweaks applied (no audio, builtin gdiplus, no gstreamer, WPF software rendering)"

# --- 6. MTGO itself ----------------------------------------------------------------------------
if [ ! -f "$(appref_unix)" ]; then
    log "Downloading and running the MTGO installer"
    dl="$(mktemp -d)"
    curl -fsSL -o "$dl/setup.exe" "$MTGO_SETUP_URL"
    "$WHISKYCMD" run "$BOTTLE" "$dl/setup.exe" >/dev/null 2>&1 &
    log "Waiting for the ClickOnce install to finish (accept any prompts in the installer window)"
    until [ -f "$(appref_unix)" ]; do sleep 10; done
    # The installer auto-starts MTGO without the CPU limit; close it and use our launcher instead.
    sleep 20; wineserver -k 2>/dev/null || true
    rm -rf "$dl"
fi
ok "MTGO installed"

# --- 7. Launcher + Desktop shortcut ------------------------------------------------------------
log "Installing launcher to $LAUNCHER_DIR"
mkdir -p "$LAUNCHER_DIR"
cp "$ROOT/lib/common.sh" "$ROOT/launcher/launch.sh" "$ROOT/src/affinity.cs" "$LAUNCHER_DIR/"
chmod +x "$LAUNCHER_DIR/launch.sh"
(cd "$LAUNCHER_DIR" && wine64 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /out:affinity.exe affinity.cs 2>&1 | grep -E ' error ' && exit 1 || true)
[ -f "$LAUNCHER_DIR/affinity.exe" ] || die "failed to compile affinity.exe"

APP="$HOME/Desktop/MTGO.app"
rm -rf "$APP"
osacompile -o "$APP" -e 'do shell script quoted form of (POSIX path of (path to home folder) & "Library/Application Support/MTGO-Launcher/launch.sh")'
# Borrow MTGO's icon from a Whisky-generated shortcut.
exe=$(find "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Apps/2.0" -name MTGO.exe -not -path '*/Data/*' 2>/dev/null | head -1)
if [ -n "$exe" ]; then
    tmp="$(mktemp -d)"
    "$WHISKYCMD" shortcut "$BOTTLE" "$exe" --name MTGOicon --output "$tmp" >/dev/null 2>&1 || true
    icns=$(find "$tmp" -name '*.icns' | head -1)
    [ -n "$icns" ] && cp "$icns" "$APP/Contents/Resources/applet.icns" && touch "$APP"
    rm -rf "$tmp"
fi
ok "Desktop shortcut: $APP"

echo
log "Done. Double-click MTGO on your Desktop. After logging in, allow a minute or two for the lobby to load."

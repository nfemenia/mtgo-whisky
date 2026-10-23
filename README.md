# MTGO on Apple Silicon (Whisky)

Sets up Magic: The Gathering Online on an M1/M2/M3 Mac with [Whisky](https://github.com/frankea/Whisky) (Wine), plus every fix needed to get it past the login screen.

## Use

```bash
./install.sh
```

Then double-click **MTGO** on the Desktop.

The first run takes about 20–30 minutes, mostly spent installing .NET 4.8. You may need to:

- click through Whisky's first-launch setup window, which downloads Wine;
- accept the MTGO installer prompt.

Re-running `install.sh` is safe. Steps that are already done get skipped. Close MTGO before re-running it.

`./uninstall.sh` removes the bottle, launcher and shortcut, but keeps Whisky.

**Requirements:** macOS on Apple Silicon and [Homebrew](https://brew.sh). Rosetta 2 is installed automatically if it's missing.

## What it does

| Step | Detail |
|---|---|
| Whisky + winetricks | `brew install --cask frankea/whisky/whisky` (the maintained fork), `brew install winetricks` |
| Bottle | Whisky bottle `MTGO`, Windows 10 |
| Runtime | `winetricks corefonts dotnet48` |
| Crash fixes | creates `AppData/LocalLow`; turns off audio (`HKCU\Software\Wine\Drivers\Audio=""`); `gdiplus=builtin`; `winegstreamer=disabled` |
| Rendering | WPF software rendering (`Avalon.Graphics\DisableHWAcceleration=1`) |
| MTGO | downloads the official `setup.exe` from Daybreak and runs it (ClickOnce install) |
| **Freeze fix** | the launcher limits MTGO to 2 CPU cores (see below) |
| Shortcut | `~/Desktop/MTGO.app` → `~/Library/Application Support/MTGO-Launcher/launch.sh` |

## The "Loading Magic Online" freeze

Under Wine, if MTGO can use every core, it hangs on *Loading Magic Online* right after login and keeps one core at 100%. Limiting it to a few cores fixes this ([pauleve/docker-mtgo#160](https://github.com/pauleve/docker-mtgo/issues/160)).

macOS has no `taskset`, and Wine ignores `start /affinity`. Wine does pass a process's CPU affinity on to the processes it starts, though. So `src/affinity.cs` (compiled inside the bottle with .NET's `csc.exe`) limits its own affinity and then opens MTGO's ClickOnce shortcut. The ClickOnce service `dfsvc.exe` starts MTGO and passes the limit on. MTGO has to be started from that shortcut, because running `MTGO.exe` directly is refused with "must be launched from the icon". The launcher stops any leftover `dfsvc.exe` first, since an old one would start MTGO without the limit.

Choose how many cores MTGO gets with `MTGO_CPUS` (a hex mask; the default is `3`, which is 2 cores):

```bash
MTGO_CPUS=1 ~/Library/Application\ Support/MTGO-Launcher/launch.sh   # 1 core: slowest, safest
MTGO_CPUS=f ~/Library/Application\ Support/MTGO-Launcher/launch.sh   # 4 cores
```

Check the limit while MTGO is running (`affinity 0x3` means cores 0 and 1):

```bash
cd ~/Library/Application\ Support/MTGO-Launcher && source common.sh && bottle_env && wine64 affinity.exe check
```

## Troubleshooting

- **MTGO's log:** `find ~/Library/Containers/com.franke.Whisky/Bottles -name mtgo.log -path '*Logs*'`
- **The bottle isn't in the Whisky app window:** open the sidebar (View → Show Sidebar). The Desktop shortcut doesn't depend on the Whisky window anyway.
- **No sound:** sound is turned off on purpose, because MTGO's audio crashes under Wine.

# homebrew-mpv

Give Homebrew's `mpv` a real Finder presence on macOS: a clickable `/Applications/mpv.app` that shows up in **Open With**, can be set as the default player for media/subtitle files, and keeps using your Homebrew-installed `mpv` binary (so `brew upgrade mpv` keeps it current).

## Why

Homebrew's formula install gives you a CLI binary:

```sh
/opt/homebrew/bin/mpv
```

Great in Terminal, but it creates no Finder-visible `.app`, so you can't double-click a video or pick mpv from "Open With". The Homebrew **cask** ships a real app but is frequently flagged as failing macOS Gatekeeper.

This repo bridges the gap: one script builds a thin `.app` that wraps the formula binary.

## How it works

`register-mpv-finder.sh` builds `/Applications/mpv.app` — a minimal bundle (no AppleScript). Its `CFBundleExecutable` is a small shell launcher at `Contents/MacOS/mpv-launcher`:

```sh
#!/bin/zsh
CONF_DIR="$HOME/.config/mpv"
if [[ ! -f "$CONF_DIR/mpv.conf" ]]; then
  mkdir -p "$CONF_DIR"
  printf 'player-operation-mode=pseudo-gui\n' > "$CONF_DIR/mpv.conf"
fi
exec "/opt/homebrew/bin/mpv" "$@"
```

When Finder opens files with the app, the launcher receives the paths as `"$@"` and execs the Homebrew binary. On first launch it seeds `~/.config/mpv/mpv.conf` with `player-operation-mode=pseudo-gui` (proper window/OSC, no quit-on-eof) — only if you don't already have a config. Your config is shared with CLI `mpv`; edit `~/.config/mpv/` and both pick it up.

## Requirements

- macOS (Apple Silicon; Homebrew at `/opt/homebrew`)
- `mpv` installed via Homebrew:
  ```sh
  brew install mpv
  ```

## Install

```sh
./register-mpv-finder.sh
```

The script:

1. Builds `/Applications/mpv.app` (launcher + `Info.plist` + icon).
2. Generates an app icon from Homebrew mpv's shipped PNGs.
3. Strips quarantine metadata and ad-hoc signs the bundle.
4. Registers it with LaunchServices and restarts Finder.

Re-run it anytime to rebuild or refresh Finder associations.

## Usage

- **Open one file:** right-click a media file → Open With → mpv.
- **Set as default for a type:** right-click a file → Get Info → "Open with" → mpv → **Change All…**.
- **First launch & Gatekeeper:** because the bundle is ad-hoc signed, macOS may block it the first time. Right-click `/Applications/mpv.app` → **Open** → Open (one time).

## File type coverage

The bundle declares document types (and backing UTI declarations) for a wide range of audio, video, and subtitle formats, including:

```text
mp4 mkv webm avi mov m4v wmv flv vob divx xvid ts mts m4a mp3 flac wav
wma aac ac3 dts ogg opus mka  ·  srt ass ssa sub idx smi ...
```

Custom `io.mpv.*` UTIs are declared via `UTImportedTypeDeclarations` so they resolve correctly in LaunchServices.

## Configuration

All config lives in `~/.config/mpv/` and is shared between the Finder app and CLI `mpv`:

- `~/.config/mpv/mpv.conf` — options (seeded with `player-operation-mode=pseudo-gui` on first launch)
- `~/.config/mpv/input.conf` — key bindings
- `~/.config/mpv/scripts/` — Lua scripts / custom GUIs (e.g. uosc)

Edits apply immediately, no rebuild. To stop pseudo-gui, change/remove that line (keep the file so it isn't re-seeded).

## Updating mpv

```sh
brew upgrade mpv
```

The app instantly uses the new version — no rebuild, no re-register.

## Uninstall

```sh
rm -rf /Applications/mpv.app
killall Finder
```

(Your `~/.config/mpv` is left untouched.)

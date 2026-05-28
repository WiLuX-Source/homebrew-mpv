# mpv Finder Registration

This folder documents the local macOS app wrapper created for the Homebrew formula install of `mpv`.

## Goal

Homebrew's formula install provides:

```sh
/opt/homebrew/bin/mpv
```

That works from Terminal, but it does not create a normal Finder-visible `.app`.

The Homebrew cask was avoided because Homebrew currently marks it as failing the macOS Gatekeeper check.

## Current App Location

The working Finder app is:

```sh
/Applications/mpv.app
```

It is a minimal hand-built `.app` bundle (no AppleScript). Its `CFBundleExecutable` is a small shell launcher at `Contents/MacOS/mpv-launcher`:

```sh
#!/bin/zsh
exec "/opt/homebrew/bin/mpv" --player-operation-mode=pseudo-gui "$@"
```

When Finder opens a media file with it, the launcher receives the file paths directly as `"$@"` and execs the Homebrew `mpv` binary in `pseudo-gui` mode (proper window/OSC, no quit-on-eof). This mirrors how mpv's own macOS bundle (`TOOLS/osxbundle.py`) works, but keeps using the Homebrew binary instead of a self-contained copy, so `brew upgrade mpv` keeps the app current.

## What Was Registered

The app bundle metadata declares support for common media files, including:

```text
3gp, aac, avi, flac, m4a, m4v, mkv, mov, mp3, mp4, mpeg, mpg, ogg, opus, ts, wav, webm, wmv
```

It also explicitly declares Matroska/MKV support:

```text
org.matroska.mkv
.mkv
video/x-matroska
audio/x-matroska
```

After editing the app metadata, the app was registered with macOS LaunchServices so Finder can show it in "Open With".

## Recreate It

Run:

```sh
./register-mpv-finder.sh
```

The script recreates `/Applications/mpv.app` (launcher script + `Info.plist` with media/MKV document types), removes quarantine metadata if present, ad-hoc signs the bundle, registers it with LaunchServices, and restarts Finder.


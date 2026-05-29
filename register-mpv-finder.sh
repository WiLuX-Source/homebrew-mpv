#!/bin/zsh
set -euo pipefail

APP_PATH="/Applications/mpv.app"
MPV_BIN="/opt/homebrew/bin/mpv"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CONF_DIR="$HOME/.config/mpv"
CONF_FILE="$CONF_DIR/mpv.conf"

# Tagged, colored logging. Color only on a TTY so piped/redirected logs stay clean.
if [[ -t 1 ]]; then
  C_INFO=$'\e[1;94m'; C_ACTION=$'\e[1;95m'; C_OK=$'\e[1;92m'; C_WARN=$'\e[1;93m'; C_ERR=$'\e[1;91m'; C_RST=$'\e[0m'
else
  C_INFO=; C_ACTION=; C_OK=; C_WARN=; C_ERR=; C_RST=
fi
log_info()   { printf '%s[INFO]%s %s\n'   "$C_INFO"   "$C_RST" "$*"; }
log_action() { printf '%s[ACTION]%s %s\n' "$C_ACTION" "$C_RST" "$*"; }
log_ok()     { printf '%s[OK]%s %s\n'     "$C_OK"     "$C_RST" "$*"; }
log_warn()   { printf '%s[WARN]%s %s\n'   "$C_WARN"   "$C_RST" "$*" >&2; }
log_err()    { printf '%s[ERROR]%s %s\n'  "$C_ERR"    "$C_RST" "$*" >&2; }

if [[ ! -x "$MPV_BIN" ]]; then
  log_err "mpv binary not found at $MPV_BIN"
  log_err "Install it with: brew install mpv"
  exit 1
fi

# Handle an existing user config before building anything. The Finder launcher
# can't prompt (no TTY), so the overwrite decision lives here. Existing config is
# backed up, never silently destroyed.
if [[ -f "$CONF_FILE" ]]; then
  log_warn "Existing mpv config found at $CONF_FILE"
  printf '%s[ACTION]%s Overwrite with default (player-operation-mode=pseudo-gui)? [y/N] ' "$C_ACTION" "$C_RST"
  read -r reply
  if [[ "$reply" == [yY]* ]]; then
    backup="$CONF_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONF_FILE" "$backup"
    print 'player-operation-mode=pseudo-gui' > "$CONF_FILE"
    log_ok "Config reset to default (backup: $backup)"
  else
    log_info "Kept existing config"
  fi
else
  log_info "No existing config; launcher will seed a default on first run"
fi

CONTENTS="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"
PLIST="$CONTENTS/Info.plist"

log_action "Building app bundle at $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Launcher: Finder execs this, it forwards file args straight to Homebrew mpv.
# Config lives entirely in ~/.config/mpv (shared with CLI mpv). On first launch,
# if the user has no mpv.conf yet, seed a default one with pseudo-gui (proper
# window/OSC, no quit-on-eof). Existing configs are never touched.
cat > "$MACOS_DIR/mpv-launcher" <<EOF
#!/bin/zsh
CONF_DIR="\$HOME/.config/mpv"
if [[ ! -f "\$CONF_DIR/mpv.conf" ]]; then
  mkdir -p "\$CONF_DIR"
  cat > "\$CONF_DIR/mpv.conf" <<'CONF'
player-operation-mode=pseudo-gui
CONF
fi
exec "$MPV_BIN" "\$@"
EOF
chmod +x "$MACOS_DIR/mpv-launcher"

# Full Info.plist. Document-type coverage + custom UTI declarations ported from
# djinn's mpv.app (laboratory.stolendata.net/~djinn/mpv_osx). The custom io.mpv.*
# UTIs only resolve because they are declared in UTImportedTypeDeclarations below.
# Omitted vs djinn: CFBundleURLTypes (URL schemes arrive via Apple Event, which a
# shell-exec launcher can't receive) and LSEnvironment MPVBUNDLE (we want Homebrew
# mpv to use ~/.config/mpv, not the bundle's Resources).
cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>mpv-launcher</string>
  <key>CFBundleIdentifier</key>
  <string>local.mpv.launcher</string>
  <key>CFBundleName</key>
  <string>mpv</string>
  <key>CFBundleDisplayName</key>
  <string>mpv</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>icon</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Audio File</string>
      <key>CFBundleTypeIconFile</key>
      <string>document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.apple.coreaudio-format</string>
        <string>com.microsoft.waveform-audio</string>
        <string>com.microsoft.windows-media-wma</string>
        <string>io.mpv.dts</string>
        <string>io.mpv.pcm</string>
        <string>org.matroska.mka</string>
        <string>org.xiph.flac</string>
        <string>org.xiph.ogg-audio</string>
        <string>public.aac-audio</string>
        <string>public.ac3-audio</string>
        <string>public.aifc.audio</string>
        <string>public.aiff-audio</string>
        <string>public.audio</string>
        <string>public.mp2</string>
        <string>public.mp3</string>
        <string>public.mpeg-4-audio</string>
        <string>public.ulaw-audio</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Movie File</string>
      <key>CFBundleTypeIconFile</key>
      <string>document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.adobe.flash.video</string>
        <string>com.apple.m4v-video</string>
        <string>com.apple.quicktime-movie</string>
        <string>com.microsoft.advanced-systems-format</string>
        <string>com.mythtv.nuv</string>
        <string>com.real.realmedia</string>
        <string>io.mpv.divx</string>
        <string>io.mpv.h263</string>
        <string>io.mpv.h264</string>
        <string>io.mpv.hevc</string>
        <string>io.mpv.mk3d</string>
        <string>io.mpv.mts</string>
        <string>io.mpv.nsv</string>
        <string>io.mpv.vcd</string>
        <string>io.mpv.vob</string>
        <string>io.mpv.webm</string>
        <string>io.mpv.wmv</string>
        <string>io.mpv.xvid</string>
        <string>io.mpv.y4m</string>
        <string>io.mpv.yuv</string>
        <string>org.matroska.mkv</string>
        <string>org.xiph.ogg-video</string>
        <string>public.3gpp2</string>
        <string>public.3gpp</string>
        <string>public.avi</string>
        <string>public.dv-movie</string>
        <string>public.flc-animation</string>
        <string>public.movie</string>
        <string>public.mpeg-2-video</string>
        <string>public.mpeg-4</string>
        <string>public.mpeg</string>
        <string>public.video</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Subtitles File</string>
      <key>CFBundleTypeIconFile</key>
      <string>document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>io.mpv.aqt</string>
        <string>io.mpv.ass</string>
        <string>io.mpv.jss</string>
        <string>io.mpv.rt</string>
        <string>io.mpv.smi</string>
        <string>io.mpv.subrip</string>
        <string>io.mpv.sub</string>
        <string>io.mpv.vobsub</string>
      </array>
    </dict>
  </array>
  <key>UTImportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>AC3 Audio</string>
      <key>UTTypeIdentifier</key><string>public.ac3-audio</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>ac3</string><string>a52</string><string>eac3</string></array>
        <key>public.mime-type</key><array><string>audio/ac3</string><string>audio/eac3</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>DTS Audio</string>
      <key>UTTypeIdentifier</key><string>io.mpv.dts</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>dts</string></array>
        <key>public.mime-type</key><array><string>audio/vnd.dts</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>Free Lossless Audio Codec</string>
      <key>UTTypeIdentifier</key><string>org.xiph.flac</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>flac</string></array>
        <key>public.mime-type</key><array><string>audio/flac</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>Matroska Audio</string>
      <key>UTTypeIdentifier</key><string>org.matroska.mka</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>mka</string></array>
        <key>public.mime-type</key><array><string>audio/matroska</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>Ogg Audio</string>
      <key>UTTypeIdentifier</key><string>org.xiph.ogg-audio</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>oga</string><string>ogg</string></array>
        <key>public.mime-type</key><array><string>audio/ogg</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>PCM Audio</string>
      <key>UTTypeIdentifier</key><string>io.mpv.pcm</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>pcm</string></array>
        <key>public.mime-type</key><array><string>audio/pcm</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>Waveform Audio</string>
      <key>UTTypeIdentifier</key><string>com.microsoft.waveform-audio</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>wav</string></array>
        <key>public.mime-type</key><array><string>audio/wav</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.audio</string></array>
      <key>UTTypeDescription</key><string>Windows Media Audio</string>
      <key>UTTypeIdentifier</key><string>com.microsoft.windows-media-wma</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>wma</string></array>
        <key>public.mime-type</key><array><string>audio/x-ms-wma</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Audio Video Interleave</string>
      <key>UTTypeIdentifier</key><string>public.avi</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>avi</string></array>
        <key>public.mime-type</key><array><string>video/x-msvideo</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>DIVX Video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.divx</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>divx</string></array>
        <key>public.mime-type</key><array><string>video/divx</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>DV Video</string>
      <key>UTTypeIdentifier</key><string>public.dv-movie</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>dv</string><string>hdv</string></array>
        <key>public.mime-type</key><array><string>video/dv</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Flash Video</string>
      <key>UTTypeIdentifier</key><string>com.adobe.flash.video</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>flv</string><string>fla</string><string>f4a</string><string>f4v</string><string>f4b</string><string>f4p</string><string>swf</string></array>
        <key>public.mime-type</key><array><string>application/vnd.adobe.flash.movie</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>MPEG-2 Transport Stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.mts</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>trp</string><string>m2t</string><string>m2ts</string><string>mts</string><string>mtv</string><string>ts</string></array>
        <key>public.mime-type</key><array><string>model/vnd.mts</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>MPEG-4 File</string>
      <key>UTTypeIdentifier</key><string>com.apple.m4v-video</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>m4v</string></array>
        <key>public.mime-type</key><array><string>video/m4v</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Matroska Video</string>
      <key>UTTypeIdentifier</key><string>org.matroska.mkv</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>mkv</string></array>
        <key>public.mime-type</key><array><string>video/matroska</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Matroska stereoscopic/3D video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.mk3d</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>mk3d</string></array>
        <key>public.mime-type</key><array><string>application/x-matroska</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string><string>org.matroska.mkv</string></array>
      <key>UTTypeDescription</key><string>WebM Video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.webm</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>webm</string></array>
        <key>public.mime-type</key><array><string>video/webm</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Ogg Video</string>
      <key>UTTypeIdentifier</key><string>org.xiph.ogg-video</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>ogm</string><string>ogv</string></array>
        <key>public.mime-type</key><array><string>video/ogg</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Real Media</string>
      <key>UTTypeIdentifier</key><string>com.real.realmedia</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>rm</string><string>rmd</string><string>rmj</string><string>rms</string><string>rmvb</string><string>rmx</string><string>rp</string><string>rpm</string><string>rv</string><string>rvx</string></array>
        <key>public.mime-type</key><array><string>application/vnd.rn-realmedia-vbr</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Nullsoft Streaming Video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.nsv</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>nsv</string></array>
        <key>public.mime-type</key><array><string>video/x-nsv</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>NuppleVideo File</string>
      <key>UTTypeIdentifier</key><string>com.mythtv.nuv</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>nuv</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Video CD File</string>
      <key>UTTypeIdentifier</key><string>io.mpv.vcd</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>vcd</string><string>svcd</string><string>dat</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Video Object</string>
      <key>UTTypeIdentifier</key><string>io.mpv.vob</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>vob</string></array>
        <key>public.mime-type</key><array><string>video/x-ms-vob</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>Windows Media Video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.wmv</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>wmv</string></array>
        <key>public.mime-type</key><array><string>video/x-ms-wmv</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>XVID Video</string>
      <key>UTTypeIdentifier</key><string>io.mpv.xvid</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>xvid</string></array>
        <key>public.mime-type</key><array><string>video/x-xvid</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>H.263 raw stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.h263</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>263</string></array>
        <key>public.mime-type</key><array><string>video/h263</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>AVC raw stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.h264</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>264</string></array>
        <key>public.mime-type</key><array><string>video/H264</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>HEVC raw stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.hevc</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>hevc</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>YUV stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.yuv</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>yuv</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.movie</string></array>
      <key>UTTypeDescription</key><string>YUV4MPEG2 stream</string>
      <key>UTTypeIdentifier</key><string>io.mpv.y4m</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>y4m</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>SubRip Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.subrip</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>srt</string></array>
        <key>public.mime-type</key><array><string>application/x-subrip</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>MicroDVD Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.sub</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>sub</string></array>
        <key>public.mime-type</key><array><string>text/plain</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>AQTitle Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.aqt</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>aqt</string></array>
        <key>public.mime-type</key><array><string>text/plain</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>JACOSub Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.jss</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>jss</string></array>
        <key>public.mime-type</key><array><string>text/plain</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>RealText Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.rt</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>rt</string></array>
        <key>public.mime-type</key><array><string>text/plain</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>SubStation Alpha Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.ass</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>ass</string><string>ssa</string></array>
        <key>public.mime-type</key><array><string>text/plain</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.data</string></array>
      <key>UTTypeDescription</key><string>VobSub Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.vobsub</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>idx</string><string>sub</string></array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
      <key>UTTypeDescription</key><string>SAMI Subtitle</string>
      <key>UTTypeIdentifier</key><string>io.mpv.smi</string>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key><array><string>smi</string><string>smil</string></array>
        <key>public.mime-type</key><array><string>application/smil</string></array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
EOF

# Build icon.icns from Homebrew mpv's shipped PNGs. If they're missing, skip
# gracefully (the CFBundleIconFile refs then just fall back to the generic icon).
log_action "Generating icon.icns from Homebrew mpv PNGs"
ICON_SRC="$(brew --prefix mpv 2>/dev/null)/share/mpv/icons/hicolor"
if [[ -f "$ICON_SRC/128x128/apps/mpv.png" ]]; then
  ICONSET="$(mktemp -d)/icon.iconset"
  mkdir -p "$ICONSET"
  /usr/bin/sips -z 16 16   "$ICON_SRC/16x16/apps/mpv.png"   --out "$ICONSET/icon_16x16.png"      >/dev/null
  /usr/bin/sips -z 32 32   "$ICON_SRC/32x32/apps/mpv.png"   --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
  /usr/bin/sips -z 32 32   "$ICON_SRC/32x32/apps/mpv.png"   --out "$ICONSET/icon_32x32.png"      >/dev/null
  /usr/bin/sips -z 64 64   "$ICON_SRC/64x64/apps/mpv.png"   --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
  /usr/bin/sips -z 128 128 "$ICON_SRC/128x128/apps/mpv.png" --out "$ICONSET/icon_128x128.png"    >/dev/null
  /usr/bin/sips -z 256 256 "$ICON_SRC/128x128/apps/mpv.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  /usr/bin/iconutil -c icns "$ICONSET" -o "$RES_DIR/icon.icns"
  cp "$RES_DIR/icon.icns" "$RES_DIR/document.icns"
  rm -rf "$(dirname "$ICONSET")"
else
  log_warn "mpv icon PNGs not found; app will use the generic icon"
fi

log_action "Validating, signing, and registering with Launch Services"
if /usr/bin/plutil -lint "$PLIST" >/dev/null; then
  log_ok "Info.plist is valid"
else
  log_err "Info.plist failed validation"
  exit 1
fi
/usr/bin/xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
if ! /usr/bin/codesign --force --deep --sign - "$APP_PATH" 2>/dev/null; then
  log_warn "ad-hoc codesign failed; Finder registration may misbehave"
fi
/usr/bin/touch "$APP_PATH"
"$LSREGISTER" -u "$APP_PATH" 2>/dev/null || true
"$LSREGISTER" -f "$APP_PATH"
/usr/bin/killall Finder 2>/dev/null || true

log_ok "Registered $APP_PATH for Finder Open With media playback."

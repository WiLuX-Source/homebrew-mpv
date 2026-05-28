#!/bin/zsh
set -euo pipefail

APP_PATH="/Applications/mpv.app"
MPV_BIN="/opt/homebrew/bin/mpv"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -x "$MPV_BIN" ]]; then
  echo "mpv binary not found at $MPV_BIN" >&2
  echo "Install it with: brew install mpv" >&2
  exit 1
fi

CONTENTS="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS/MacOS"
PLIST="$CONTENTS/Info.plist"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"

# Launcher: Finder execs this, it forwards file args straight to Homebrew mpv.
# pseudo-gui gives proper window/OSC behavior and no quit-on-eof.
cat > "$MACOS_DIR/mpv-launcher" <<EOF
#!/bin/zsh
exec "$MPV_BIN" --player-operation-mode=pseudo-gui "\$@"
EOF
chmod +x "$MACOS_DIR/mpv-launcher"

# Minimal Info.plist skeleton; document types added below.
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
</dict>
</plist>
EOF

/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes array' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0 dict' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeName string "Media files"' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate' "$PLIST"

/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array' "$PLIST"
for ext in 3gp aac avi flac m4a m4v mkv mov mp3 mp4 mpeg mpg ogg opus ts wav webm wmv; do
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions: string $ext" "$PLIST"
done

/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:CFBundleTypeMIMETypes array' "$PLIST"
for mime in video/x-matroska video/webm video/mp4 video/quicktime audio/mpeg audio/flac; do
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeMIMETypes: string $mime" "$PLIST"
done

/usr/libexec/PlistBuddy -c 'Add :CFBundleDocumentTypes:0:LSItemContentTypes array' "$PLIST"
for uti in public.movie public.video public.audio public.audiovisual-content public.mpeg-4 public.mpeg com.microsoft.avi org.matroska.mkv; do
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes: string $uti" "$PLIST"
done

/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations array' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0 dict' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeIdentifier string org.matroska.mkv' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeDescription string "Matroska Video"' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeConformsTo array' "$PLIST"
for parent in public.movie public.audiovisual-content public.data; do
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo: string $parent" "$PLIST"
done
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification dict' "$PLIST"
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array' "$PLIST"
for ext in mkv mk3d mka mks; do
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension: string $ext" "$PLIST"
done
/usr/libexec/PlistBuddy -c 'Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.mime-type array' "$PLIST"
for mime in video/x-matroska audio/x-matroska; do
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.mime-type: string $mime" "$PLIST"
done

/usr/bin/plutil -lint "$PLIST"
/usr/bin/xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
if ! /usr/bin/codesign --force --deep --sign - "$APP_PATH" 2>/dev/null; then
  echo "warning: ad-hoc codesign failed; Finder registration may misbehave" >&2
fi
/usr/bin/touch "$APP_PATH"
"$LSREGISTER" -u "$APP_PATH" 2>/dev/null || true
"$LSREGISTER" -f "$APP_PATH"
/usr/bin/killall Finder 2>/dev/null || true

echo "Registered $APP_PATH for Finder Open With media playback."

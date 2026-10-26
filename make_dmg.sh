#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Clipboard Manager.app"
STAGING="$BUILD/dmg-staging"
RW_DMG="$BUILD/ClipboardManager-rw.dmg"
FINAL_DMG="$BUILD/ClipboardManager-2.0-universal.dmg"
MOUNT_POINT="/Volumes/Clipboard Manager"
BACKGROUND="$ROOT/Resources/dmg-background.png"

if [ ! -d "$APP" ]; then
    "$ROOT/build.sh"
fi

if [ ! -f "$BACKGROUND" ] || [ "$ROOT/scripts/generate_dmg_background.swift" -nt "$BACKGROUND" ]; then
    "$ROOT/scripts/generate_dmg_background.sh"
fi

DMGBUILD_BIN="${DMGBUILD:-}"
if [ -z "$DMGBUILD_BIN" ] && command -v dmgbuild >/dev/null 2>&1; then
    DMGBUILD_BIN="$(command -v dmgbuild)"
fi

if [ -n "$DMGBUILD_BIN" ]; then
    echo "Using dmgbuild for a Finder-free, reproducible DMG layout."
    rm -f "$FINAL_DMG"
    DMG_ROOT="$ROOT" "$DMGBUILD_BIN" \
        -s "$ROOT/scripts/dmg_settings.py" \
        "Clipboard Manager" \
        "$FINAL_DMG"
    hdiutil verify "$FINAL_DMG" >/dev/null
    echo
    echo "Created: $FINAL_DMG"
    ls -lh "$FINAL_DMG"
    exit 0
fi

rm -f "$FINAL_DMG" "$RW_DMG"
rm -rf "$STAGING"
mkdir -p "$STAGING/.background"

cp -R "$APP" "$STAGING/Clipboard Manager.app"
ln -s /Applications "$STAGING/Applications"
cp "$BACKGROUND" "$STAGING/.background/background.png"
chflags hidden "$STAGING/.background" 2>/dev/null || true

hdiutil create \
    -volname "Clipboard Manager" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -quiet \
    "$RW_DMG"

hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
hdiutil attach "$RW_DMG" -nobrowse -noautoopen -quiet

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
}
trap cleanup EXIT

if osascript <<'APPLESCRIPT'
tell application "Finder"
    activate
    tell disk "Clipboard Manager"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 180, 860, 608}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 104
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Clipboard Manager.app" of container window to {165, 190}
        set position of item "Applications" of container window to {495, 190}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT
then
    echo "Applied Finder window layout."
else
    echo "Warning: Finder layout could not be applied; the DMG still contains the app and Applications shortcut."
fi

sync
sleep 1
hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet
hdiutil verify "$FINAL_DMG" >/dev/null

rm -f "$RW_DMG"
rm -rf "$STAGING"

echo
echo "Created: $FINAL_DMG"
ls -lh "$FINAL_DMG"

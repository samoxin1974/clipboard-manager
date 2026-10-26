#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$ROOT/Resources"
BASE="$RESOURCES/AppIcon-1024.png"
ICONSET="$RESOURCES/AppIcon.iconset"

mkdir -p "$RESOURCES"
xcrun swift "$ROOT/scripts/generate_icon.swift" "$BASE"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16 "$BASE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$BASE" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

echo "Created $RESOURCES/AppIcon.icns"

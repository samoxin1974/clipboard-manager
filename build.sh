#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Clipboard Manager.app"
MIN_MACOS="14.0"

if [ ! -f "$ROOT/Resources/AppIcon.icns" ] || [ "$ROOT/scripts/generate_icon.swift" -nt "$ROOT/Resources/AppIcon.icns" ]; then
    "$ROOT/scripts/generate_icon.sh"
fi

mkdir -p "$BUILD"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=()
while IFS= read -r -d '' file; do
    SOURCES+=("$file")
done < <(find "$ROOT/Sources" -name '*.swift' -print0)

echo "Compiling Intel build..."
xcrun --sdk macosx swiftc \
    -O \
    -parse-as-library \
    -swift-version 5 \
    -target "x86_64-apple-macos$MIN_MACOS" \
    "${SOURCES[@]}" \
    -lsqlite3 \
    -o "$BUILD/ClipboardManager-x86_64"

echo "Compiling Apple Silicon build..."
xcrun --sdk macosx swiftc \
    -O \
    -parse-as-library \
    -swift-version 5 \
    -target "arm64-apple-macos$MIN_MACOS" \
    "${SOURCES[@]}" \
    -lsqlite3 \
    -o "$BUILD/ClipboardManager-arm64"

lipo -create \
    "$BUILD/ClipboardManager-x86_64" \
    "$BUILD/ClipboardManager-arm64" \
    -output "$APP/Contents/MacOS/ClipboardManager"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo
echo "Built: $APP"
file "$APP/Contents/MacOS/ClipboardManager"
du -sh "$APP"

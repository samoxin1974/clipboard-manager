#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/Resources/dmg-background.png"

mkdir -p "$ROOT/Resources"
xcrun swift "$ROOT/scripts/generate_dmg_background.swift" "$OUTPUT"
echo "Created $OUTPUT"

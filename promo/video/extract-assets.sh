#!/bin/bash
# Gathers everything the video's desktop needs from this Mac into promo/video/assets (not committed).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p assets
swift extract-icons.swift assets
WALL="/System/Library/ExtensionKit/Extensions/NeptuneOneWallpaper.appex/Contents/Resources"
sips -s format jpeg -s formatOptions 92 "$WALL/TahoeDark.heic" --out assets/wallpaper-dark.jpg >/dev/null
sips -s format jpeg -s formatOptions 92 "$WALL/TahoeLight.heic" --out assets/wallpaper-light.jpg >/dev/null
cp ../../docs/media/icon-256.png assets/icons/remain-small.png
echo "Done: $(ls assets/icons | wc -l | tr -d ' ') icons, $(ls assets/symbols | wc -l | tr -d ' ') symbols, 2 wallpapers"

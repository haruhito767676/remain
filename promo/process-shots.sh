#!/bin/bash
# Turns raw screenshots into the files the README and the site use.
#
#   bash promo/process-shots.sh <folder with raw screenshots> [output folder]
#
# Raw names look like  menu-idle-dark-ja.png  /  settings-top-light-en.png.
# Windows (settings, welcome, about) get a drop shadow; menus were captured with their surroundings
# and are used as they are. Everything is written as WebP to docs/media/shot-<name>.webp.
set -euo pipefail
cd "$(dirname "$0")/.."
RAW="${1:?folder with raw screenshots}"
OUT="${2:-docs/media}"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for file in "$RAW"/*.png; do
    name="$(basename "$file" .png)"
    case "$name" in
        settings-*|welcome-*|about-*) swift promo/shadow.swift "$file" "$TMP/$name.png" ;;
        *) cp "$file" "$TMP/$name.png" ;;
    esac
    cwebp -quiet -q 92 -alpha_q 100 -m 6 "$TMP/$name.png" -o "$OUT/shot-$name.webp"
done
echo "Wrote $(ls "$OUT"/shot-*.webp | wc -l | tr -d ' ') images to $OUT"

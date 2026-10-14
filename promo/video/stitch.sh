#!/bin/bash
# Joins the recorded scene clips into one video: promo/video/out/remain-intro-<lang>.mp4 (no sound yet).
#   promo/video/stitch.sh [lang]
set -euo pipefail
cd "$(dirname "$0")/out"
lang="${1:-en}"
list="concat-$lang.txt"; : > "$list"
for scene in 0 1 2 3 5 6 7; do echo "file 'clip-$scene-$lang.mp4'" >> "$list"; done
ffmpeg -y -loglevel error -f concat -safe 0 -i "$list" -c copy -movflags +faststart "remain-intro-$lang.mp4"
rm -f "$list"
ffprobe -v error -show_entries format=duration -of csv=p=0 "remain-intro-$lang.mp4" | awk '{printf "remain-intro-'"$lang"'.mp4: %.1f s\n", $1}'

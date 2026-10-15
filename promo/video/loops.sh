#!/bin/bash
# Cuts short, text-free loops for the README out of the video scenes: docs/media/loop-<name>.webp
#   promo/video/loops.sh [name...]     names: hero lid agents stop (default: all)
set -euo pipefail
cd "$(dirname "$0")"
out=../../docs/media
mkdir -p out/loopframes
make() { # name scene range
  local name=$1 scene=$2 range=$3 dur
  node record.mjs --nocap --tag "-$name" --range "$range" "$scene"
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "out/clip-$scene-en-$name.mp4")
  rm -rf out/loopframes/$name; mkdir -p out/loopframes/$name
  ffmpeg -y -loglevel error -i "out/clip-$scene-en-$name.mp4" -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=$(echo "$dur - 0.5" | bc):d=0.5,fps=12,scale=800:-1" "out/loopframes/$name/%04d.png"
  img2webp -loop 0 -lossy -q 70 -m 6 -d 83 out/loopframes/$name/*.png -o "$out/loop-$name.webp" >/dev/null
  ls -la "$out/loop-$name.webp" | awk '{printf "loop-'"$name"'.webp: %.1f MB\n", $5/1048576}'
}
want=${*:-hero lid agents stop}
for n in $want; do
  case $n in
    hero) make hero 2 16-27 ;;
    lid) make lid 5 0.6-11.8 ;;
    agents) make agents 3 0-17.8 ;;
    stop) make stop 3 17-27.5 ;;
  esac
done

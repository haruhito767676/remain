#!/bin/bash
# Builds build/remAIn.app (ad-hoc signed). The CLI is bundled in Contents/Helpers/remain.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="build/remAIn.app"

# One build per architecture, merged with lipo (works without a full Xcode install).
for arch in arm64 x86_64; do
    swift build -c release --triple "${arch}-apple-macosx"
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
universal() { # <product> <destination>
    lipo -create \
        ".build/arm64-apple-macosx/release/$1" \
        ".build/x86_64-apple-macosx/release/$1" \
        -output "$2"
}
universal RemainApp "$APP/Contents/MacOS/RemainApp"
universal remain "$APP/Contents/Helpers/remain"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string></array>
    <key>CFBundleName</key><string>remAIn</string>
    <key>CFBundleDisplayName</key><string>remAIn</string>
    <key>CFBundleIdentifier</key><string>dev.remain.app</string>
    <key>CFBundleExecutable</key><string>RemainApp</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

# Localizations (English is the source language and needs no table).
if [ -d Resources ]; then
    mkdir -p "$APP/Contents/Resources"
    cp -R Resources/*.lproj "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP"
echo "Built $APP"

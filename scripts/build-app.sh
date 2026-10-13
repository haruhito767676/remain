#!/bin/bash
# Builds build/remAIn.app (ad-hoc signed). The CLI is bundled in Contents/Helpers/remain.
set -euo pipefail
cd "$(dirname "$0")/.."

# The version comes from the single source of truth in the code unless the caller overrides it.
VERSION="${VERSION:-$(sed -n 's/.*remainVersion = "\(.*\)"/\1/p' Sources/RemainCore/Version.swift)}"
APP="build/remAIn.app"
# Build number: the CI run number, else the commit count. (Shown as "Version 1.0.0 (42)" in About.)
BUILD="${GITHUB_RUN_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

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
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 haruhito767676. MIT License.</string>
</dict>
</plist>
PLIST

# Localizations (English is the source language and needs no table).
mkdir -p "$APP/Contents/Resources"
if [ -d Resources ]; then
    cp -R Resources/*.lproj "$APP/Contents/Resources/"
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"
echo "Built $APP"

#!/bin/bash
# Builds CLN.app into ./build and zips it for a GitHub release.
# Run: ./build_app.sh            (version 1.0.0, macOS 14 and later)
#      ./build_app.sh 1.0.1      (a new version: the in-app updater offers it once released)
#      ./build_app.sh --macos12  (the macOS 12 Monterey edition, version 0.0.0, for Intel and
#                                 Apple chips, into build/macOS12/ as CLN_macOS12.zip)
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--macos12" ]; then
  LEGACY=1; VERSION="0.0.0"; MIN_OS="12.0"; OUT="build/macOS12"; ZIP="CLN_macOS12.zip"
else
  LEGACY=0; VERSION="${1:-1.0.0}"; MIN_OS="14.0"; OUT="build"; ZIP="CLN.zip"
fi
BUILD_NUMBER=$(echo "$VERSION" | awk -F. '{ printf "%d", $1 * 10000 + $2 * 100 + $3 }')

APP="$OUT/CLN.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ "$LEGACY" = 1 ]; then
  # 2015-2019 Macs are Intel, so this one carries both Intel and Apple chip code.
  export CLN_MACOS12=1
  BINS=()
  for ARCH in arm64 x86_64; do
    FLAGS=(-c release -Xswiftc -DLEGACY --triple "$ARCH-apple-macosx12.0" --scratch-path ".build/macos12-$ARCH")
    swift build "${FLAGS[@]}"
    BINS+=("$(swift build "${FLAGS[@]}" --show-bin-path)/CLN")
  done
  lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/CLN"
else
  FLAGS=(-c release)
  swift build "${FLAGS[@]}"
  cp "$(swift build "${FLAGS[@]}" --show-bin-path)/CLN" "$APP/Contents/MacOS/CLN"
fi

# App icon
ICONSET=build/CLN.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/make_icon.swift build/icon_1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CLN</string>
  <key>CFBundleDisplayName</key><string>CLN</string>
  <key>CFBundleIdentifier</key><string>com.lilyfleurs.cln</string>
  <key>CFBundleExecutable</key><string>CLN</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>CLN asks Finder to empty the Trash and to remove apps that need your password.</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"

# The zip to attach to the GitHub release. Always named CLN.zip, so the download button
# (releases/latest/download/CLN.zip) and the in-app updater find the newest one.
rm -f "$OUT/$ZIP"
ditto -c -k --keepParent "$APP" "$OUT/$ZIP"
echo "Built $APP ($VERSION, macOS $MIN_OS+) and $OUT/$ZIP"

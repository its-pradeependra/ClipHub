#!/bin/bash
#
# Builds ClipHub (Release) and packages it into the signed, designed DMG:
# custom background with drag-to-Applications layout, volume icon, signed image.
#
# Usage: scripts/release-dmg.sh [output-dir]     (default output: dist/)
#
# Override the signing identity with CLIPHUB_SIGN_IDENTITY. Once enrolled in the
# Apple Developer Program, switch it to your "Developer ID Application: …"
# certificate and add notarization after the sign step:
#   xcrun notarytool submit "$DMG" --keychain-profile AC_PASSWORD --wait
#   xcrun stapler staple "$DMG"
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$REPO/dist}"
DERIVED="$REPO/build/DerivedData"
SIGN_IDENTITY="${CLIPHUB_SIGN_IDENTITY:-Apple Development: pradeependrapratap@gmail.com (WX2FG4K33K)}"
VOLNAME="ClipHub"

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Building Release…"
xcodebuild -project "$REPO/Maccy.xcodeproj" -scheme Maccy -configuration Release \
  -derivedDataPath "$DERIVED" -quiet build
APP="$DERIVED/Build/Products/Release/ClipHub.app"
[ -d "$APP" ] || { echo "error: build product not found at $APP" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "==> Version $VERSION"

echo "==> Rendering DMG background…"
swift "$REPO/scripts/dmg-background.swift" "$VERSION" "$WORK/bg1x.png" "$WORK/bg2x.png"
sips -s format tiff "$WORK/bg1x.png" --out "$WORK/bg1x.tiff" >/dev/null
sips -s format tiff "$WORK/bg2x.png" --out "$WORK/bg2x.tiff" >/dev/null
tiffutil -cathidpicheck "$WORK/bg1x.tiff" "$WORK/bg2x.tiff" -out "$WORK/background.tiff" 2>/dev/null

echo "==> Staging…"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/ClipHub.app"
ln -s /Applications "$STAGE/Applications"
cp "$WORK/background.tiff" "$STAGE/.background/background.tiff"

# A stale mount with the same name would push the new one to "ClipHub 1".
[ -d "/Volumes/$VOLNAME" ] && hdiutil detach "/Volumes/$VOLNAME" >/dev/null 2>&1 || true

echo "==> Creating writable image…"
RW="$WORK/rw.dmg"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null
MOUNT="$(hdiutil attach "$RW" -noautoopen | tail -1 | awk -F'\t' '{print $NF}' | sed 's/[[:space:]]*$//')"
[ -d "$MOUNT" ] || { echo "error: mount failed" >&2; exit 1; }

echo "==> Applying Finder layout…"
osascript - "$(basename "$MOUNT")" <<'EOF'
on run argv
  set volName to item 1 of argv
  tell application "Finder"
    tell disk volName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set the bounds of container window to {200, 120, 860, 542}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 100
      set text size of viewOptions to 12
      set background picture of viewOptions to file ".background:background.tiff"
      set position of item "ClipHub.app" of container window to {165, 210}
      set position of item "Applications" of container window to {495, 210}
      update without registering applications
      delay 2
      close
    end tell
  end tell
end run
EOF

# Volume icon must come AFTER the Finder layout — Finder rewrites the volume's
# metadata when saving the view options and wipes a previously applied icon.
echo "==> Applying volume icon…"
cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -a C "$MOUNT"
sync
hdiutil detach "$MOUNT" >/dev/null
MOUNT=""

echo "==> Compressing and signing…"
mkdir -p "$OUT_DIR"
DMG="$OUT_DIR/ClipHub-$VERSION.dmg"
rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
codesign --force --sign "$SIGN_IDENTITY" "$DMG"
codesign --verify "$DMG"

# Give the .dmg file itself the app icon (resource fork; local Finder polish).
swift -e "import AppKit; exit(NSWorkspace.shared.setIcon(NSImage(contentsOfFile: \"$APP/Contents/Resources/AppIcon.icns\"), forFile: \"$DMG\") ? 0 : 1)"

echo "==> Done: $DMG"

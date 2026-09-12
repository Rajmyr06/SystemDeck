#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

[[ "$(uname -s)" == "Darwin" ]] || { echo "error: macOS is required" >&2; exit 1; }

for tool in swift iconutil codesign hdiutil ditto shasum /usr/libexec/PlistBuddy; do
  if [[ "$tool" == /* ]]; then
    [[ -x "$tool" ]] || { echo "error: missing $tool" >&2; exit 1; }
  else
    command -v "$tool" >/dev/null 2>&1 || { echo "error: missing $tool" >&2; exit 1; }
  fi
done

./validate.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
DIST="$PWD/dist"
APP="$DIST/SystemDeck.app"
ZIP="$DIST/SystemDeck-$VERSION-macOS.zip"
DMG="$DIST/SystemDeck-$VERSION-macOS.dmg"
STAGE="$DIST/.dmg-stage"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/SystemDeck" "$APP/Contents/MacOS/SystemDeck"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/SystemDeck"

iconutil -c icns Packaging/AppIcon.iconset -o "$APP/Contents/Resources/SystemDeck.icns"

codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

mkdir -p "$STAGE"
ditto "$APP" "$STAGE/SystemDeck.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "SystemDeck $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

(
  cd "$DIST"
  shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt
)

echo
echo "Release created in $DIST"
echo "  SystemDeck.app"
echo "  $(basename "$ZIP")"
echo "  $(basename "$DMG")"
echo "  SHA256SUMS.txt"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="OnCue"
PROJECT="$ROOT/OnCue.xcodeproj"
SCHEME="OnCue"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/OnCueReleaseDerivedData}"
DIST="$ROOT/dist"
DMG_ROOT="$DIST/dmg-root"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DMG_PATH="$DIST/$APP_NAME.dmg"

echo "Building $APP_NAME ($CONFIGURATION)..."
rm -rf "$DERIVED_DATA" "$DIST"
mkdir -p "$DMG_ROOT"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  ONLY_ACTIVE_ARCH=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build finished, but $APP_PATH was not found." >&2
  exit 1
fi

echo "Creating DMG..."
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Created: $DMG_PATH"
echo
echo "Note: this script defaults to an unsigned local DMG."
echo "For public distribution, sign with Developer ID and notarize before publishing."

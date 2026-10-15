#!/bin/bash
# Bygger TurboTast.app.
#
#   ./build.sh               bygg for denne Macen
#   ./build.sh --install     bygg, kopier til /Applications og start
#   ./build.sh --release     bygg for både Apple Silicon og Intel, og lag build/TurboTast.zip
#
# Versjonsnummer settes med VERSION=1.2.0 ./build.sh (ellers brukes det i Info.plist).
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
# Bygg og signer utenfor prosjektmappen: iCloud-synkronisering av ~/Documents
# legger på filattributter som får codesign til å feile.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/TurboTast.app"
BIN="$APP/Contents/MacOS/TurboTast"
rm -rf build
mkdir -p build "$APP/Contents/MacOS"

compile() { # $1 = arkitektur, $2 = utfil
    swiftc -O -swift-version 5 -target "$1-apple-macos15.0" Sources/*.swift -o "$2"
}

if [[ "$MODE" == "--release" ]]; then
    compile arm64 "$STAGE/TurboTast-arm64"
    compile x86_64 "$STAGE/TurboTast-x86_64"
    lipo -create "$STAGE/TurboTast-arm64" "$STAGE/TurboTast-x86_64" -output "$BIN"
else
    compile "$(uname -m)" "$BIN"
fi

cp Info.plist "$APP/Contents/"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION#v}" "$APP/Contents/Info.plist"
fi
xattr -cr "$APP"

# Med et utviklersertifikat beholder appen Tilgjengelighet-tilgangen etter ny bygging.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID/ { print $2; exit }')
codesign --force --sign "${IDENTITY:--}" --identifier com.olai.TurboTast "$APP"
codesign --verify --strict "$APP"
ditto "$APP" build/TurboTast.app
echo "Bygget build/TurboTast.app (signert med: ${IDENTITY:-ad hoc})"

case "$MODE" in
    --install)
        pkill -x TurboTast || true
        rm -rf /Applications/TurboTast.app
        cp -R "$APP" /Applications/
        open /Applications/TurboTast.app
        echo "Installert i /Applications og startet."
        ;;
    --release)
        ditto -c -k --keepParent "$APP" build/TurboTast.zip
        echo "Laget build/TurboTast.zip"
        ;;
esac

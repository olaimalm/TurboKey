#!/bin/bash
# Builds TurboKey.app.
#
#   ./build.sh               build for this Mac
#   ./build.sh --install     build, copy to /Applications and launch
#   ./build.sh --release     build for both Apple Silicon and Intel, and create build/TurboKey.zip
#
# Set the version with VERSION=1.2.0 ./build.sh (otherwise the one in Info.plist is used).
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
# Build and sign outside the project folder: iCloud syncing of ~/Documents
# adds extended attributes that make codesign fail.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/TurboKey.app"
BIN="$APP/Contents/MacOS/TurboKey"
rm -rf build
mkdir -p build "$APP/Contents/MacOS"

compile() { # $1 = architecture, $2 = output file
    swiftc -O -swift-version 5 -target "$1-apple-macos15.0" Sources/*.swift -o "$2"
}

if [[ "$MODE" == "--release" ]]; then
    compile arm64 "$STAGE/TurboKey-arm64"
    compile x86_64 "$STAGE/TurboKey-x86_64"
    lipo -create "$STAGE/TurboKey-arm64" "$STAGE/TurboKey-x86_64" -output "$BIN"
else
    compile "$(uname -m)" "$BIN"
fi

cp Info.plist "$APP/Contents/"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION#v}" "$APP/Contents/Info.plist"
fi
xattr -cr "$APP"

# With a developer certificate the app keeps its Accessibility access across rebuilds.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID/ { print $2; exit }')
codesign --force --sign "${IDENTITY:--}" --identifier com.olai.TurboKey "$APP"
codesign --verify --strict "$APP"
ditto "$APP" build/TurboKey.app
echo "Built build/TurboKey.app (signed with: ${IDENTITY:-ad hoc})"

case "$MODE" in
    --install)
        pkill -x TurboKey || true
        rm -rf /Applications/TurboKey.app
        cp -R "$APP" /Applications/
        open /Applications/TurboKey.app
        echo "Installed to /Applications and launched."
        ;;
    --release)
        ditto -c -k --keepParent "$APP" build/TurboKey.zip
        echo "Created build/TurboKey.zip"
        ;;
esac

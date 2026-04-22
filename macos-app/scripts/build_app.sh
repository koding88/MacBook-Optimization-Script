#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"

BUILD_DIR="$APP_DIR/.build/release"
BUNDLE_OUTPUT_DIR="$APP_DIR/build"
APP_BUNDLE_DIR="$BUNDLE_OUTPUT_DIR/MacBook Optimization.app"
EXECUTABLE="$BUILD_DIR/MacBookOptimizationApp"
ICON_SOURCE="$REPO_ROOT/assets/branding/app-icon.png"
ICON_OUTPUT="$BUNDLE_OUTPUT_DIR/AppIcon.icns"
INFO_PLIST="$APP_DIR/packaging/macos/Info.plist"
ICON_TOOL="$SCRIPT_DIR/create_icns.sh"

echo "Building release binary..."
swift build -c release --package-path "$APP_DIR"

mkdir -p "$BUNDLE_OUTPUT_DIR"

if [ -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    "$ICON_TOOL" "$ICON_SOURCE" "$ICON_OUTPUT"
fi

echo "Preparing .app bundle..."
rm -rf "$APP_BUNDLE_DIR"
mkdir -p "$APP_BUNDLE_DIR/Contents/MacOS" "$APP_BUNDLE_DIR/Contents/Resources"

cp "$INFO_PLIST" "$APP_BUNDLE_DIR/Contents/Info.plist"
if [ -f "$ICON_OUTPUT" ]; then
    cp "$ICON_OUTPUT" "$APP_BUNDLE_DIR/Contents/Resources/AppIcon.icns"
fi

# CFBundleExecutable should point at the real Mach-O app binary. Using a shell
# wrapper here confuses LaunchServices and can lead to incorrect Dock icon/app
# identity behavior.
cp "$EXECUTABLE" "$APP_BUNDLE_DIR/Contents/MacOS/MacBookOptimizationApp"
chmod +x "$APP_BUNDLE_DIR/Contents/MacOS/MacBookOptimizationApp"

echo
echo "App bundle created at:"
echo "$APP_BUNDLE_DIR"

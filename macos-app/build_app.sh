#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_DIR="$SCRIPT_DIR/build/MacBook Optimization.app"
EXECUTABLE="$BUILD_DIR/MacBookOptimizationApp"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_SOURCE="$REPO_ROOT/icon.png"
ICON_OUTPUT="$SCRIPT_DIR/AppBundle/Contents/Resources/AppIcon.icns"

echo "Building release binary..."
swift build -c release --package-path "$SCRIPT_DIR"

if [ -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    "$SCRIPT_DIR/tools/create_icns.sh" "$ICON_SOURCE" "$ICON_OUTPUT"
fi

echo "Preparing .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$SCRIPT_DIR/AppBundle/Contents/Info.plist" "$APP_DIR/Contents/Info.plist"
if [ -f "$ICON_OUTPUT" ]; then
    cp "$ICON_OUTPUT" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/MacOS/MacBookOptimizationApp" <<EOF
#!/bin/bash
set -euo pipefail
exec "\$(dirname "\$0")/MacBookOptimizationApp.bin"
EOF

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/MacBookOptimizationApp.bin"
chmod +x "$APP_DIR/Contents/MacOS/MacBookOptimizationApp"
chmod +x "$APP_DIR/Contents/MacOS/MacBookOptimizationApp.bin"

echo "App bundle created at:"
echo "$APP_DIR"

#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MacBook Optimization.app"
SOURCE_APP="$SCRIPT_DIR/build/$APP_NAME"
TARGET_MODE="${1:-dist}"

case "$TARGET_MODE" in
    dist)
        TARGET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/dist"
        ;;
    desktop)
        TARGET_DIR="$HOME/Desktop"
        ;;
    *)
        echo "Usage: $0 [dist|desktop]"
        exit 1
        ;;
esac

"$SCRIPT_DIR/build_app.sh"

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_DIR/$APP_NAME"
cp -R "$SOURCE_APP" "$TARGET_DIR/$APP_NAME"

echo "Released app to:"
echo "$TARGET_DIR/$APP_NAME"

#!/bin/bash

set -euo pipefail

SOURCE_PNG="${1:-}"
OUTPUT_ICNS="${2:-}"

if [ -z "$SOURCE_PNG" ] || [ -z "$OUTPUT_ICNS" ]; then
    echo "Usage: $0 /path/to/icon.png /path/to/AppIcon.icns"
    exit 1
fi

WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/AppIcon.iconset"
BASE_ICON="$WORK_DIR/icon-base.png"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ICONSET_DIR"

WIDTH="$(sips -g pixelWidth "$SOURCE_PNG" | awk '/pixelWidth:/{print $2}')"
HEIGHT="$(sips -g pixelHeight "$SOURCE_PNG" | awk '/pixelHeight:/{print $2}')"

if [ "$WIDTH" != "$HEIGHT" ]; then
    EDGE="$WIDTH"
    if [ "$HEIGHT" -lt "$EDGE" ]; then
        EDGE="$HEIGHT"
    fi
    sips -c "$EDGE" "$EDGE" "$SOURCE_PNG" --out "$BASE_ICON" >/dev/null
else
    cp "$SOURCE_PNG" "$BASE_ICON"
fi

sips -Z 1024 "$BASE_ICON" --out "$BASE_ICON" >/dev/null

generate_icon() {
    local size="$1"
    local filename="$2"
    sips -z "$size" "$size" "$BASE_ICON" --out "$ICONSET_DIR/$filename" >/dev/null
}

generate_icon 16 "icon_16x16.png"
generate_icon 32 "icon_16x16@2x.png"
generate_icon 32 "icon_32x32.png"
generate_icon 64 "icon_32x32@2x.png"
generate_icon 128 "icon_128x128.png"
generate_icon 256 "icon_128x128@2x.png"
generate_icon 256 "icon_256x256.png"
generate_icon 512 "icon_256x256@2x.png"
generate_icon 512 "icon_512x512.png"
generate_icon 1024 "icon_512x512@2x.png"

mkdir -p "$(dirname "$OUTPUT_ICNS")"
iconutil --convert icns --output "$OUTPUT_ICNS" "$ICONSET_DIR"

echo "Created icns at $OUTPUT_ICNS"

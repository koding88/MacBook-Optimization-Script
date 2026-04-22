#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/.." && pwd)"

APP_NAME="MacBook Optimization.app"
VOLUME_NAME="MacBook Optimization"
SOURCE_APP="$APP_DIR/build/$APP_NAME"
TARGET_MODE="${1:-dist}"
DMG_NAME="MacBookOptimizationApp.dmg"

detach_volume_if_needed() {
    local volume_name="$1"
    local mount_point

    while mount_point="$(find /Volumes -maxdepth 1 -type d -name "${volume_name}*" -print -quit 2>/dev/null)"; do
        [ -z "$mount_point" ] && break
        hdiutil detach "$mount_point" >/dev/null 2>&1 || break
    done
}

configure_dmg_layout() {
    local mounted_volume_name="$1"
    local app_name="$2"

    osascript - "$mounted_volume_name" "$app_name" <<'APPLESCRIPT'
on run argv
    set volumeName to item 1 of argv
    set appName to item 2 of argv

    tell application "Finder"
        tell disk volumeName
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set bounds to {120, 120, 760, 430}
            end tell

            tell icon view options of container window
                set arrangement to not arranged
                set icon size to 128
                set text size to 16
            end tell

            set position of item appName of container window to {180, 170}
            set position of item "Applications" of container window to {470, 170}

            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
APPLESCRIPT
}

case "$TARGET_MODE" in
    dist)
        TARGET_DIR="$REPO_ROOT/dist"
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

if [ "$TARGET_MODE" = "dist" ]; then
    TMP_WORK_DIR="$(mktemp -d)"
    STAGING_DIR="$TMP_WORK_DIR/dmg-root"
    RW_DMG_PATH="$TMP_WORK_DIR/${DMG_NAME%.dmg}-rw.dmg"
    trap 'rm -rf "$TMP_WORK_DIR"' EXIT

    mkdir -p "$STAGING_DIR"
    rm -f "$TARGET_DIR/$DMG_NAME"
    cp -R "$SOURCE_APP" "$STAGING_DIR/$APP_NAME"
    ln -s /Applications "$STAGING_DIR/Applications"

    detach_volume_if_needed "$VOLUME_NAME"

    hdiutil create \
        -volname "$VOLUME_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDRW \
        "$RW_DMG_PATH" >/dev/null

    ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen)"
    DEVICE_IDENTIFIER="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS|Apple_APFS/ {print $1; exit}')"
    MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
    MOUNTED_VOLUME_NAME="$(basename "$MOUNT_POINT")"

    configure_dmg_layout "$MOUNTED_VOLUME_NAME" "$APP_NAME"
    sync
    hdiutil detach "$DEVICE_IDENTIFIER" >/dev/null

    hdiutil convert \
        "$RW_DMG_PATH" \
        -ov \
        -format UDZO \
        -o "$TARGET_DIR/$DMG_NAME" >/dev/null
fi

echo
echo "Released app to:"
echo "$TARGET_DIR/$APP_NAME"

if [ "$TARGET_MODE" = "dist" ]; then
    echo "Created DMG at:"
    echo "$TARGET_DIR/$DMG_NAME"
fi

#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE_DIR="$APP_DIR/build/MacBook Optimization.app"

if [ ! -d "$APP_BUNDLE_DIR" ]; then
    "$SCRIPT_DIR/build_app.sh"
fi

open "$APP_BUNDLE_DIR"

#!/bin/bash

# ==============================================================================
# Module: plugin_loader.sh
# Purpose: Extensible plugin scanner and dynamic module registration
# ==============================================================================

PLUGIN_DIR="$SCRIPT_DIR/plugins"

function load_plugins() {
    if [ ! -d "$PLUGIN_DIR" ]; then
        mkdir -p "$PLUGIN_DIR" 2>/dev/null
        return 0
    fi

    for plugin in "$PLUGIN_DIR"/*.sh; do
        if [ -f "$plugin" ] && [ -r "$plugin" ]; then
            source "$plugin" 2>/dev/null
            log_info "Loaded external plugin: $(basename "$plugin")"
        fi
    done
}

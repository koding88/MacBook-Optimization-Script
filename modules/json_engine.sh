#!/bin/bash

# ==============================================================================
# Module: json_engine.sh
# Purpose: Native AWK/Bash structured JSON reader & writer for state & backups
# ==============================================================================

JSON_STATE_FILE="$HOME/.macbook_optimizer_state.json"

function json_init_state() {
    if [ ! -f "$JSON_STATE_FILE" ]; then
        echo '{"version": "3.0", "optimizations": {}}' > "$JSON_STATE_FILE" 2>/dev/null
    fi
}

function json_set_value() {
    local feature_id="$1"
    local status="$2"
    local timestamp="$3"
    
    json_init_state

    # Use AWK to update or insert state in JSON format
    local tmp_file="/tmp/mbo_state_$$.json"
    awk -v id="$feature_id" -v st="$status" -v ts="$timestamp" '
    BEGIN { updated = 0 }
    {
        if ($0 ~ "\"" id "\":") {
            print "    \"" id "\": {\"status\": \"" st "\", \"timestamp\": \"" ts "\"},"
            updated = 1
        } else if ($0 ~ /"optimizations": \{/ && updated == 0) {
            print $0
            print "    \"" id "\": {\"status\": \"" st "\", \"timestamp\": \"" ts "\"},"
            updated = 1
        } else {
            print $0
        }
    }
    ' "$JSON_STATE_FILE" > "$tmp_file" 2>/dev/null

    if [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$JSON_STATE_FILE" 2>/dev/null
    else
        rm -f "$tmp_file" 2>/dev/null
    fi
}

function json_get_status() {
    local feature_id="$1"
    if [ ! -f "$JSON_STATE_FILE" ]; then
        echo "not_run"
        return
    fi
    
    local line=$(grep -A 1 "\"" feature_id "\":" "$JSON_STATE_FILE" 2>/dev/null | grep "status" || true)
    if [ -n "$line" ]; then
        echo "$line" | cut -d'"' -f4
    else
        echo "not_run"
    fi
}

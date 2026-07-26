#!/bin/bash

# ==============================================================================
# Module: logger.sh
# Purpose: Structured file logging with timestamps and log levels
# ==============================================================================

LOG_FILE="$HOME/.macbook_optimizer.log"

function log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Append to log file safely
    if [ -w "$HOME" ] || [ -w "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    fi
}

function log_info() {
    log_msg "INFO" "$1"
}

function log_warn() {
    log_msg "WARN" "$1"
}

function log_error() {
    log_msg "ERROR" "$1"
}

function view_log_file() {
    if [ -f "$LOG_FILE" ] && [ -r "$LOG_FILE" ]; then
        echo -e "${BLUE}=== System Optimization Log File ($LOG_FILE) ===${NC}"
        tail -n 40 "$LOG_FILE"
    else
        echo -e "${YELLOW}No log file found or log file empty.${NC}"
    fi
}

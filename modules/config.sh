#!/bin/bash

# ==============================================================================
# Module: config.sh
# Purpose: Configuration management, state logging, and safe command execution
# ==============================================================================

CONFIG_FILE="$HOME/.macbook_optimizer_state.conf"
DRY_RUN=false
NON_INTERACTIVE=false

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function initialize_config() {
    local config_dir=$(dirname "$CONFIG_FILE")
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir" 2>/dev/null || {
            echo -e "${RED}Error: Cannot create config directory $config_dir${NC}"
            log_error "Cannot create config directory $config_dir"
            return 1
        }
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        if touch "$CONFIG_FILE" 2>/dev/null; then
            chmod 644 "$CONFIG_FILE" 2>/dev/null
        else
            echo -e "${RED}Error: Cannot create config file $CONFIG_FILE${NC}"
            log_error "Cannot create config file $CONFIG_FILE"
            return 1
        fi
    fi
    
    if [ ! -w "$CONFIG_FILE" ]; then
        if chmod 644 "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}Fixed permissions for config file${NC}"
        else
            echo -e "${RED}Error: Config file exists but is not writable${NC}"
            log_error "Config file exists but is not writable"
            return 1
        fi
    fi

    # Initialize JSON State engine
    json_init_state
    
    return 0
}

function add_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Wrapper to safely run commands with Dry-Run support
function safe_exec() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] Would execute:${NC} $@"
        log_info "[DRY-RUN] Executed command preview: $@"
        return 0
    else
        log_info "Executing command: $@"
        "$@"
        return $?
    fi
}

function execute_task_status() {
    local exit_code=$1
    local message="$2"
    local feature_id="$3"
    local timestamp=$(add_timestamp)
    local status_message
    local config_entry
    local status_str="enabled"

    if [ "$exit_code" -eq 0 ]; then
        status_message="${GREEN}✓ Success: $message${NC}"
        config_entry="$feature_id=enabled|$timestamp"
        status_str="enabled"
        log_info "Task Succeeded: $message ($feature_id)"
    else
        status_message="${RED}✗ Error ($exit_code): $message${NC}"
        config_entry="$feature_id=failed|$timestamp"
        status_str="failed"
        log_error "Task Failed ($exit_code): $message ($feature_id)"
    fi
    
    echo -e "$status_message"
    
    if [ -n "$feature_id" ] && [ "$DRY_RUN" != true ]; then
        write_to_config "$config_entry"
        json_set_value "$feature_id" "$status_str" "$timestamp"
    fi

    return $exit_code
}

function check_status() {
    local exit_code=$?
    execute_task_status "$exit_code" "$1" "$2"
}

function write_to_config() {
    local entry="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        initialize_config || return 1
    fi
    
    if [ ! -w "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot write to config file (permission denied)${NC}"
        return 1
    fi
    
    if echo "$entry" >> "$CONFIG_FILE" 2>/dev/null; then
        return 0
    else
        echo -e "${RED}Error: Failed to write to config file${NC}"
        return 1
    fi
}

function safe_read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    if [ ! -r "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot read config file (permission denied)${NC}"
        return 1
    fi
    
    return 0
}

function get_feature_status() {
    local feature=$1
    echo -e "\n${BLUE}Feature Status Report:${NC}"
    echo -e "${BLUE}------------------${NC}"
    
    if ! safe_read_config; then
        echo -e "Feature: ${YELLOW}$feature${NC}"
        echo -e "Status: ${RED}config file not accessible${NC}"
        echo -e "${BLUE}------------------${NC}\n"
        return 1
    fi
    
    if grep -q "^$feature=" "$CONFIG_FILE" 2>/dev/null; then
        local line=$(grep "^$feature=" "$CONFIG_FILE" | tail -n 1)
        local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
        local timestamp=$(echo "$line" | cut -d'|' -f2)
        echo -e "Feature: ${YELLOW}$feature${NC}"
        if [ "$status" = "enabled" ]; then
            echo -e "Status: ${GREEN}$status${NC}"
        else
            echo -e "Status: ${RED}$status${NC}"
        fi
        echo -e "Last Run: $timestamp"
    else
        echo -e "Feature: ${YELLOW}$feature${NC}"
        echo -e "Status: ${YELLOW}never run${NC}"
    fi
    echo -e "${BLUE}------------------${NC}\n"
}

function show_all_statuses() {
    echo -e "\n${BLUE}Complete System Status Report (v3.0 Engine)${NC}"
    echo -e "${BLUE}==========================================${NC}"
    
    if ! safe_read_config; then
        echo -e "${RED}Cannot access configuration file${NC}"
        return 1
    fi
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No optimizations have been run yet.${NC}"
        return 0
    fi

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local feature=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
            local timestamp=$(echo "$line" | cut -d'|' -f2)
            
            echo -e "${YELLOW}$feature${NC}:"
            if [ "$status" = "enabled" ]; then
                echo -e "  Status: ${GREEN}$status${NC}"
            else
                echo -e "  Status: ${RED}$status${NC}"
            fi
            echo -e "  Last Run: $timestamp"
            echo -e "${BLUE}------------------${NC}"
        fi
    done < "$CONFIG_FILE"
}
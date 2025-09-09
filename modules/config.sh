#!/bin/bash

# Configuration constants
CONFIG_FILE="$HOME/.macbook_optimizer_state.conf"

# Colors for status messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize configuration
function initialize_config() {
    # Create config directory if it doesn't exist
    local config_dir=$(dirname "$CONFIG_FILE")
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir" 2>/dev/null || {
            echo -e "${RED}Error: Cannot create config directory $config_dir${NC}"
            return 1
        }
    fi
    
    # Create config file with proper permissions
    if [ ! -f "$CONFIG_FILE" ]; then
        if touch "$CONFIG_FILE" 2>/dev/null; then
            chmod 644 "$CONFIG_FILE" 2>/dev/null
        else
            echo -e "${RED}Error: Cannot create config file $CONFIG_FILE${NC}"
            echo -e "${YELLOW}Please check your home directory permissions${NC}"
            return 1
        fi
    fi
    
    # Ensure the file is writable by current user
    if [ ! -w "$CONFIG_FILE" ]; then
        # Try to fix permissions
        if chmod 644 "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}Fixed permissions for config file${NC}"
        else
            echo -e "${RED}Error: Config file exists but is not writable${NC}"
            echo -e "${YELLOW}Try running: chmod 644 $CONFIG_FILE${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Status tracking functions
function add_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

function check_status() {
    local timestamp=$(add_timestamp)
    local status_message
    local config_entry
    
    if [ $? -eq 0 ]; then
        status_message="${GREEN}Success: $1${NC}"
        config_entry="$2=enabled|$timestamp"
    else
        status_message="${RED}Error: $1${NC}"
        config_entry="$2=failed|$timestamp"
    fi
    
    echo -e "$status_message"
    
    # Safely write to config file with permission checks
    if write_to_config "$config_entry"; then
        return 0
    else
        echo -e "${YELLOW}Warning: Could not save status to config file${NC}"
        return 1
    fi
}

# Safe function to write to config file
function write_to_config() {
    local entry="$1"
    
    # Check if config file is accessible
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Config file doesn't exist, attempting to create...${NC}"
        initialize_config || return 1
    fi
    
    # Check write permissions
    if [ ! -w "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot write to config file (permission denied)${NC}"
        echo -e "${YELLOW}Config file location: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please run: chmod 644 $CONFIG_FILE${NC}"
        return 1
    fi
    
    # Attempt to write to file
    if echo "$entry" >> "$CONFIG_FILE" 2>/dev/null; then
        return 0
    else
        echo -e "${RED}Error: Failed to write to config file${NC}"
        return 1
    fi
}

# Safe function to read from config file
function safe_read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    if [ ! -r "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot read config file (permission denied)${NC}"
        echo -e "${YELLOW}Config file location: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please run: chmod 644 $CONFIG_FILE${NC}"
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
    echo -e "\n${BLUE}Complete System Status Report${NC}"
    echo -e "${BLUE}===========================${NC}"
    
    if ! safe_read_config; then
        echo -e "${RED}Cannot access configuration file${NC}"
        return 1
    fi
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No optimizations have been run yet.${NC}"
        return
    fi

    while IFS= read -r line; do
        if [ -n "$line" ]; then  # Skip empty lines
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
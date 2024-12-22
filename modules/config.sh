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
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
    fi
}

# Status tracking functions
function add_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

function check_status() {
    local timestamp=$(add_timestamp)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success: $1${NC}"
        echo "$2=enabled|$timestamp" >> "$CONFIG_FILE"
    else
        echo -e "${RED}Error: $1${NC}"
        echo "$2=failed|$timestamp" >> "$CONFIG_FILE"
    fi
}

function get_feature_status() {
    local feature=$1
    echo -e "\n${BLUE}Feature Status Report:${NC}"
    echo -e "${BLUE}------------------${NC}"
    if grep -q "^$feature=" "$CONFIG_FILE"; then
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
    
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No optimizations have been run yet.${NC}"
        return
    fi

    while IFS= read -r line; do
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
    done < "$CONFIG_FILE"
} 
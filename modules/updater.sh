#!/bin/bash

# ==============================================================================
# Module: updater.sh
# Purpose: Auto-update checker and git synchronization
# ==============================================================================

CURRENT_VERSION="3.0.0"

function check_for_updates() {
    echo -e "${BLUE}Checking for MacBook Optimization Script updates...${NC}"
    
    if is_command_available "git" && [ -d "$SCRIPT_DIR/.git" ]; then
        cd "$SCRIPT_DIR" || return 1
        git fetch origin main 2>/dev/null
        local status=$(git status -uno 2>/dev/null | grep "behind" || true)
        if [ -n "$status" ]; then
            echo -e "${YELLOW}An update is available! Run './script.sh --update' to apply.${NC}"
        else
            echo -e "${GREEN}✓ MacBook Optimization Script is up-to-date (v$CURRENT_VERSION).${NC}"
        fi
    else
        echo -e "${YELLOW}Not a git repository or git command not available.${NC}"
    fi
}

function apply_update() {
    echo -e "${BLUE}Updating MacBook Optimization Script...${NC}"
    
    if is_command_available "git" && [ -d "$SCRIPT_DIR/.git" ]; then
        cd "$SCRIPT_DIR" || return 1
        if git pull origin main 2>/dev/null; then
            echo -e "${GREEN}✓ Successfully updated to latest release.${NC}"
        else
            echo -e "${RED}Failed to pull updates from git repository.${NC}"
        fi
    else
        echo -e "${RED}Error: Cannot auto-update outside of a git workspace.${NC}"
    fi
}

#!/bin/bash

# ==============================================================================
# Module: performance_tweaks.sh
# Purpose: Spotlight control, animation adjustments, and Dock optimizations
# ==============================================================================

function disable_spotlight() {
    echo -e "${BLUE}Managing Spotlight indexing...${NC}"
    
    local spot_choice="1"
    if [ "$NON_INTERACTIVE" != true ]; then
        echo "1. Disable Spotlight indexing"
        echo "2. Enable Spotlight indexing"
        read -p "Enter choice (1-2, default 1): " user_choice
        if [ -n "$user_choice" ]; then
            spot_choice="$user_choice"
        fi
    fi
    
    local status_code=0
    if [ "$spot_choice" = "1" ]; then
        safe_exec sudo mdutil -a -i off 2>/dev/null || status_code=$?
        execute_task_status $status_code "Spotlight indexing disabled" "spotlight"
    elif [ "$spot_choice" = "2" ]; then
        safe_exec sudo mdutil -a -i on 2>/dev/null || status_code=$?
        execute_task_status $status_code "Spotlight indexing enabled" "spotlight"
    else
        echo -e "${YELLOW}Invalid choice, operation skipped.${NC}"
    fi
}

function disable_dashboard() {
    echo -e "${BLUE}Checking Dashboard feature status...${NC}"
    
    if [ "$OS_MAJOR_VERSION" -ge 11 ] || [[ "$OS_VERSION" == 10.15* ]]; then
        echo -e "${YELLOW}Notice: Dashboard was permanently removed by Apple in macOS 10.15 Catalina and later.${NC}"
        echo -e "${GREEN}No action needed on macOS $OS_VERSION.${NC}"
        execute_task_status 0 "Dashboard (Not present on macOS $OS_VERSION)" "dashboard"
        return 0
    fi

    backup_setting "mcx-disabled" "com.apple.dashboard" "mcx-disabled"

    safe_exec defaults write com.apple.dashboard mcx-disabled -boolean YES 2>/dev/null
    safe_exec killall Dock 2>/dev/null
    execute_task_status 0 "Dashboard disabled" "dashboard"
}

function disable_animations() {
    echo -e "${BLUE}Optimizing system window animations...${NC}"
    
    backup_setting "NSAutomaticWindowAnimationsEnabled" "NSGlobalDomain" "NSAutomaticWindowAnimationsEnabled"
    backup_setting "NSWindowResizeTime" "NSGlobalDomain" "NSWindowResizeTime"
    backup_setting "launchanim" "com.apple.dock" "launchanim"

    safe_exec defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false 2>/dev/null
    safe_exec defaults write NSGlobalDomain NSWindowResizeTime -float 0.001 2>/dev/null
    safe_exec defaults write com.apple.dock launchanim -bool false 2>/dev/null
    
    safe_exec killall Dock 2>/dev/null
    execute_task_status 0 "System animations optimized" "animations"
}

function optimize_dock() {
    echo -e "${BLUE}Optimizing Dock responsiveness...${NC}"
    
    backup_setting "launchanim" "com.apple.dock" "launchanim"
    backup_setting "expose-animation-duration" "com.apple.dock" "expose-animation-duration"
    backup_setting "springboard-show-duration" "com.apple.dock" "springboard-show-duration"
    backup_setting "springboard-hide-duration" "com.apple.dock" "springboard-hide-duration"

    safe_exec defaults write com.apple.dock launchanim -bool false 2>/dev/null
    safe_exec defaults write com.apple.dock expose-animation-duration -float 0 2>/dev/null
    safe_exec defaults write com.apple.dock springboard-show-duration -int 0 2>/dev/null
    safe_exec defaults write com.apple.dock springboard-hide-duration -int 0 2>/dev/null
    
    safe_exec killall Dock 2>/dev/null
    execute_task_status 0 "Dock responsiveness optimized" "dock_optimization"
}
#!/bin/bash

# ==============================================================================
# Module: rollback.sh
# Purpose: Revert system optimizations to exact backup state or macOS defaults
# ==============================================================================

function restore_performance_defaults() {
    echo -e "${YELLOW}Restoring Dock & Animation defaults...${NC}"
    
    defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null
    defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null
    defaults delete com.apple.dock launchanim 2>/dev/null
    defaults delete com.apple.dock expose-animation-duration 2>/dev/null
    defaults delete com.apple.dock springboard-show-duration 2>/dev/null
    defaults delete com.apple.dock springboard-hide-duration 2>/dev/null
    
    killall Dock 2>/dev/null
    execute_task_status 0 "Dock & Animations restored to defaults" "animations"
}

function restore_spotlight_defaults() {
    echo -e "${YELLOW}Re-enabling Spotlight indexing...${NC}"
    sudo mdutil -a -i on 2>/dev/null
    execute_task_status $? "Spotlight indexing re-enabled" "spotlight"
}

function restore_power_defaults() {
    echo -e "${YELLOW}Restoring default power settings...${NC}"
    
    sudo pmset -a displaysleep 10 2>/dev/null
    sudo pmset -a disksleep 10 2>/dev/null
    sudo pmset -a womp 1 2>/dev/null
    sudo pmset -a lowpowermode 0 2>/dev/null
    sudo pmset -a lessbright 1 2>/dev/null
    sudo pmset -a halfdim 1 2>/dev/null
    
    execute_task_status $? "Power settings restored to defaults" "power_optimization"
}

function rollback_all_optimizations() {
    echo -e "${RED}=== Rollback All System Optimizations ===${NC}"
    echo -e "${YELLOW}This will restore modified settings to original backup state or system defaults.${NC}"
    
    if [ "$NON_INTERACTIVE" != true ]; then
        read -p "Are you sure you want to proceed? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Rollback cancelled.${NC}"
            return 0
        fi
    fi

    # Try restoring from exact user backup file first
    if restore_from_backup; then
        echo -e "${GREEN}✓ Successfully restored settings from user backup file.${NC}"
    else
        echo -e "${YELLOW}No user backup file found; restoring generic macOS defaults...${NC}"
        restore_performance_defaults
        restore_spotlight_defaults
        restore_power_defaults
    fi

    # Reset config tracking state
    if [ -f "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE" 2>/dev/null
        initialize_config
    fi

    log_info "Rollback performed successfully"
    echo -e "${GREEN}✓ All optimization states have been reset.${NC}"
}

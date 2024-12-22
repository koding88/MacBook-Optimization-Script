#!/bin/bash

# Power Management Functions

function optimize_power() {
    echo "Optimizing power settings..."
    
    # Power management optimizations
    sudo pmset -a displaysleep 15
    sudo pmset -a disksleep 10
    sudo pmset -a womp 1
    sudo pmset -a networkoversleep 0
    
    check_status "Power settings optimized" "power_optimization"
}

function toggle_power_saving() {
    echo "Power Saving Mode Management..."
    
    # Get current power saving status
    local current_mode=$(pmset -g | grep lowpowermode | awk '{print $2}')
    
    if [ "$current_mode" = "1" ]; then
        # Disable power saving mode
        sudo pmset -a lowpowermode 0
        check_status "Power saving mode disabled" "power_saving"
    else
        # Enable power saving mode
        sudo pmset -a lowpowermode 1
        # Additional power saving optimizations
        sudo pmset -a displaysleep 5
        sudo pmset -a disksleep 5
        sudo pmset -a sleep 10
        sudo pmset -a lessbright 1
        sudo pmset -a halfdim 1
        check_status "Power saving mode enabled" "power_saving"
    fi
    
    # Show current power settings
    echo -e "\n${BLUE}Current Power Settings:${NC}"
    pmset -g
} 
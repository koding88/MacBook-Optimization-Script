#!/bin/bash

# ==============================
# 🔋 macOS Power Management Optimization
# ==============================

# Define Colors for Output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Function to Display Status
function check_status() {
    local message=$1
    echo -e "${GREEN}[✔] $message${NC}"
}

# ==============================
# ⚡ Power Management Functions
# ==============================

# 1️⃣ Optimize Power Settings (General)
function optimize_power() {
    echo -e "${YELLOW}Optimizing power settings...${NC}"

    # Power management optimizations
    sudo pmset -a displaysleep 15   # Screen sleeps after 15 minutes
    sudo pmset -a disksleep 10      # Disk sleeps after 10 minutes
    sudo pmset -a womp 1            # Wake on network access enabled
    sudo pmset -a networkoversleep 0 # Disable unnecessary network wake-ups

    check_status "Power settings optimized"
}

# 2️⃣ Toggle Power Saving Mode (Automatic Adjustment)
function toggle_power_saving() {
    echo -e "${YELLOW}Power Saving Mode Management...${NC}"

    # Get current power saving status
    local current_mode=$(pmset -g | grep lowpowermode | awk '{print $2}')

    if [ "$current_mode" = "1" ]; then
        # Disable power saving mode
        sudo pmset -a lowpowermode 0
        check_status "Power saving mode disabled"
    else
        # Enable power saving mode
        sudo pmset -a lowpowermode 1
        sudo pmset -a displaysleep 5  # Reduce screen sleep time
        sudo pmset -a disksleep 5     # Reduce disk sleep time
        sudo pmset -a sleep 10        # Enable system sleep after 10 minutes
        sudo pmset -a lessbright 1    # Lower brightness
        sudo pmset -a halfdim 1       # Dim screen when idle

        check_status "Power saving mode enabled"
    fi

    # Show current power settings
    echo -e "\n${BLUE}Current Power Settings:${NC}"
    pmset -g
}

# 3️⃣ Maximum Power Saving (For Battery Mode)
function max_power_saving() {
    echo -e "${YELLOW}Enabling Maximum Power Saving Mode...${NC}"

    sudo pmset -b lowpowermode 1     # Enable Low Power Mode on battery
    sudo pmset -b displaysleep 3     # Screen sleep after 3 minutes
    sudo pmset -b disksleep 3        # Disk sleep after 3 minutes
    sudo pmset -b sleep 5            # System sleep after 5 minutes
    sudo pmset -b lessbright 1       # Reduce brightness
    sudo pmset -b halfdim 1          # Dim screen when idle
    sudo pmset -b womp 0             # Disable wake on network access

    check_status "Maximum Power Saving Mode enabled (Battery Mode)"
}

# 4️⃣ Show Current Power Settings
function show_power_settings() {
    echo -e "${BLUE}Current Power Settings:${NC}"
    pmset -g
}

# ==============================
# 🔋 Power Optimization Menu
# ==============================

function run_power_optimization() {
    while true; do
        clear
        echo -e "${BLUE}=== macOS Power Optimization ===${NC}"
        echo -e "${YELLOW}1.${NC} Optimize General Power Settings"
        echo -e "${YELLOW}2.${NC} Toggle Power Saving Mode"
        echo -e "${YELLOW}3.${NC} Enable Maximum Power Saving (Battery)"
        echo -e "${YELLOW}4.${NC} Show Current Power Settings"
        echo -e "${YELLOW}0.${NC} Exit"

        read -p "Enter your choice (0-4): " choice

        case $choice in
            1) optimize_power ;;
            2) toggle_power_saving ;;
            3) max_power_saving ;;
            4) show_power_settings ;;
            0) echo -e "${GREEN}Exiting Power Optimization Tool.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 4.${NC}" ;;
        esac

        echo -e "\nPress Enter to return to the menu..."
        read
    done
}

# Run Power Optimization Menu
run_power_optimization

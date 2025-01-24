#!/bin/bash

# ==============================
# macOS Performance Optimization
# ==============================

# Define Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Function to Check Command Availability
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed. Please install it first.${NC}"
        exit 1
    fi
}

# Function to Display Status
function check_status() {
    local message=$1
    echo -e "${GREEN}[✔] $message${NC}"
}

# ==============================
#  Performance Optimization Functions
# ==============================

# 1️Disable Spotlight Indexing
function disable_spotlight() {
    sudo mdutil -a -i off
    check_status "Spotlight indexing disabled"
}

# Disable Dashboard (Saves CPU & RAM)
function disable_dashboard() {
    defaults write com.apple.dashboard mcx-disabled -boolean YES
    killall Dock
    check_status "Dashboard disabled"
}

# Disable Animations (Boost Speed)
function disable_animations() {
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.dock launchanim -bool false
    killall Dock
    check_status "Animations disabled"
}

# Optimize Dock (Instant Response)
function optimize_dock() {
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0
    defaults write com.apple.dock springboard-show-duration -int 0
    defaults write com.apple.dock springboard-hide-duration -int 0
    killall Dock
    check_status "Dock animations disabled"
}

# Free Up RAM and Optimize Memory
function optimize_memory() {
    sudo purge
    check_status "RAM memory cleaned"
}

# Reduce Transparency (Boosts Performance)
function reduce_transparency() {
    defaults write com.apple.universalaccess reduceTransparency -bool true
    check_status "Transparency effects reduced"
}

# Stop Background Processes That Slow Down macOS
function stop_background_services() {
    launchctl unload -w /System/Library/LaunchAgents/com.apple.SafariCloudHistoryPushAgent.plist 2>/dev/null
    launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null
    check_status "Unnecessary background processes stopped"
}

#  Clean System Cache and Logs
function clean_system() {
    sudo rm -rf ~/Library/Caches/*
    sudo rm -rf /Library/Caches/*
    sudo rm -rf ~/Library/Logs/*
    sudo rm -rf /Library/Logs/*
    check_status "System cache and logs cleaned"
}

# Speed Up Boot Time (Disable Unnecessary Startup Items)
function optimize_startup() {
    sudo launchctl disable system/com.apple.mdmclient.daemon
    check_status "Startup processes optimized"
}

# Improve Disk Performance (Enable TRIM for SSDs)
function enable_trim() {
    sudo trimforce enable
    check_status "TRIM enabled for SSD"
}

# ==============================
#  Optimization Menu
# ==============================

function run_optimization() {
    while true; do
        clear
        echo -e "${BLUE}=== macOS Performance Optimization ===${NC}"
        echo -e "${YELLOW}1.${NC} Disable Spotlight Indexing"
        echo -e "${YELLOW}2.${NC} Disable Dashboard"
        echo -e "${YELLOW}3.${NC} Disable Animations"
        echo -e "${YELLOW}4.${NC} Optimize Dock"
        echo -e "${YELLOW}5.${NC} Free Up RAM"
        echo -e "${YELLOW}6.${NC} Reduce Transparency Effects"
        echo -e "${YELLOW}7.${NC} Stop Background Services"
        echo -e "${YELLOW}8.${NC} Clean System Cache & Logs"
        echo -e "${YELLOW}9.${NC} Optimize Startup"
        echo -e "${YELLOW}10.${NC} Enable TRIM (for SSD)"
        echo -e "${YELLOW}11.${NC} Run All Optimizations"
        echo -e "${YELLOW}0.${NC} Exit"

        read -p "Enter your choice (0-11): " choice

        case $choice in
            1) disable_spotlight ;;
            2) disable_dashboard ;;
            3) disable_animations ;;
            4) optimize_dock ;;
            5) optimize_memory ;;
            6) reduce_transparency ;;
            7) stop_background_services ;;
            8) clean_system ;;
            9) optimize_startup ;;
            10) enable_trim ;;
            11)
                disable_spotlight
                disable_dashboard
                disable_animations
                optimize_dock
                optimize_memory
                reduce_transparency
                stop_background_services
                clean_system
                optimize_startup
                enable_trim
                ;;
            0) echo -e "${GREEN}Exiting optimization tool.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 11.${NC}" ;;
        esac

        echo -e "\nPress Enter to return to the menu..."
        read
    done
}

# Run Optimization Menu
run_optimization

#!/bin/bash

# ==============================
# 🚀 macOS Performance & Security Optimization
# ==============================

# Define Colors for Output
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
# ⚡ System Optimization Functions
# ==============================

# 1️⃣ Optimize System Performance
function optimize_system_performance() {
    echo -e "${YELLOW}Optimizing system performance...${NC}"

    # Enhancing system performance
    sudo sysctl -w kern.ipc.somaxconn=2048
    sudo sysctl -w kern.ipc.nmbclusters=65536
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000

    check_status "System performance optimized"
}

# 2️⃣ Optimize Memory Management
function optimize_memory_management() {
    echo -e "${YELLOW}Optimizing memory management...${NC}"

    # Purge inactive memory
    sudo purge

    # Disable sudden motion sensor if it's a MacBook with HDD
    sudo pmset -a sms 0

    # Set memory pressure parameters
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000

    # Clear system caches
    sudo sync
    sudo purge

    check_status "Memory management optimized"
}

# 3️⃣ Optimize SSD Performance
function optimize_ssd() {
    echo -e "${YELLOW}Optimizing SSD settings...${NC}"

    # Enable TRIM for SSD
    sudo trimforce enable

    # Disable hibernation (Not needed for SSDs)
    sudo pmset -a hibernatemode 0

    # Remove sleep image to free up space
    sudo rm -f /var/vm/sleepimage

    check_status "SSD optimized"
}

# 4️⃣ Optimize macOS Security
function optimize_security() {
    echo -e "${YELLOW}Optimizing security settings...${NC}"

    # Enable Firewall
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

    # Enable Stealth Mode (Blocks ICMP ping requests)
    sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1

    # Only allow signed applications
    sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1

    # Disable remote login (Prevents SSH attacks)
    sudo systemsetup -setremotelogin off

    # Disable guest account (Improves security)
    sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

    check_status "Security settings optimized"
}

# 5️⃣ Clean System Cache and Unused Files
function clean_system() {
    echo -e "${YELLOW}Cleaning system cache and logs...${NC}"

    sudo rm -rf ~/Library/Caches/*
    sudo rm -rf /Library/Caches/*
    sudo rm -rf ~/Library/Logs/*
    sudo rm -rf /Library/Logs/*
    
    sudo purge

    check_status "System cache and logs cleaned"
}

# 6️⃣ Reduce Background Services
function stop_background_services() {
    echo -e "${YELLOW}Stopping unnecessary background services...${NC}"

    # Disable Safari iCloud Sync
    launchctl unload -w /System/Library/LaunchAgents/com.apple.SafariCloudHistoryPushAgent.plist 2>/dev/null

    # Disable Apple Music Background Process
    launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null

    check_status "Background services stopped"
}

# ==============================
# 🛠️ Optimization Menu
# ==============================

function run_optimization() {
    while true; do
        clear
        echo -e "${BLUE}=== macOS Performance & Security Optimization ===${NC}"
        echo -e "${YELLOW}1.${NC} Optimize System Performance"
        echo -e "${YELLOW}2.${NC} Optimize Memory Management"
        echo -e "${YELLOW}3.${NC} Optimize SSD Performance"
        echo -e "${YELLOW}4.${NC} Optimize Security Settings"
        echo -e "${YELLOW}5.${NC} Clean System Cache & Logs"
        echo -e "${YELLOW}6.${NC} Stop Background Services"
        echo -e "${YELLOW}7.${NC} Run All Optimizations"
        echo -e "${YELLOW}0.${NC} Exit"

        read -p "Enter your choice (0-7): " choice

        case $choice in
            1) optimize_system_performance ;;
            2) optimize_memory_management ;;
            3) optimize_ssd ;;
            4) optimize_security ;;
            5) clean_system ;;
            6) stop_background_services ;;
            7)
                optimize_system_performance
                optimize_memory_management
                optimize_ssd
                optimize_security
                clean_system
                stop_background_services
                ;;
            0) echo -e "${GREEN}Exiting optimization tool.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 7.${NC}" ;;
        esac

        echo -e "\nPress Enter to return to the menu..."
        read
    done
}

# Run Optimization Menu
run_optimization

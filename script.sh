#!/bin/bash

# ==============================
# 🚀 macOS Optimization Script
# ==============================

# Define Colors for Output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Log file for error tracking
LOG_FILE="/tmp/mac_optimization.log"

# Function to log errors
function log_error() {
    echo -e "$(date) - ${RED}ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

# ==============================
# 📌 Source All Modules Safely
# ==============================

MODULES=(
    "config.sh"
    "ui_components.sh"
    "system_optimizations.sh"
    "network_optimizations.sh"
    "storage_optimizations.sh"
    "performance_tweaks.sh"
    "maintenance.sh"
    "system_monitoring.sh"
    "power_management.sh"
)

MODULES_DIR="./modules"

# Ensure all required modules are sourced
for module in "${MODULES[@]}"; do
    if [ -f "$MODULES_DIR/$module" ]; then
        source "$MODULES_DIR/$module"
    else
        log_error "Missing module: $MODULES_DIR/$module"
        exit 1
    fi
done

# ==============================
# 📌 Main Script Execution
# ==============================

function main() {
    initialize_config  # Ensure config is initialized

    while true; do
        clear
        display_main_menu  # Show the menu
        handle_user_choice # Handle the user's choice

        # Ask the user if they want to exit after every operation
        echo -e "\n${YELLOW}Press Enter to continue, or type 'exit' to quit...${NC}"
        read -r user_input
        if [[ "$user_input" == "exit" ]]; then
            echo -e "${GREEN}Exiting script... Goodbye!${NC}"
            exit 0
        fi
    done
}

# Start the script
main

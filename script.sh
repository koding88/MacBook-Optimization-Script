#!/bin/bash

# Source all modules
source ./modules/config.sh
source ./modules/ui_components.sh
source ./modules/system_optimizations.sh
source ./modules/network_optimizations.sh
source ./modules/storage_optimizations.sh
source ./modules/performance_tweaks.sh
source ./modules/maintenance.sh
source ./modules/system_monitoring.sh
source ./modules/power_management.sh
source ./modules/menu_handler.sh

# Main script execution
function main() {
    echo -e "${BLUE}Initializing 1245ym's MacBook Optimization Script...${NC}"
    
    if ! initialize_config; then
        echo -e "${RED}Failed to initialize configuration. Script may not work properly.${NC}"
        echo -e "${YELLOW}Press any key to continue anyway, or Ctrl+C to exit...${NC}"
        read -n 1 -s
    fi
    
    while true; do
        clear
        display_main_menu
        handle_user_choice
    done
}

# Start the script
main

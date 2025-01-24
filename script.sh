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
    initialize_config
    
    while true; do
        clear
        display_main_menu
        handle_user_choice
        if [ $? -eq 0 ]; then
            break
        fi
    done
}

# Start the script
main
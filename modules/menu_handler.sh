#!/bin/bash

# Menu Handler Function

function handle_user_choice() {
    read -p "Enter your choice: " choice
    echo ""  # Add a blank line for better readability

    case $choice in
        1)
            optimize_system_performance
            get_feature_status "system_performance"
            return 1
            ;;
        2)
            optimize_memory_management
            get_feature_status "memory_management"
            return 1
            ;;
        3)
            optimize_ssd
            get_feature_status "ssd_optimization"
            return 1
            ;;
        4)
            optimize_security
            get_feature_status "security_optimization"
            return 1
            ;;
        5)
            optimize_power
            get_feature_status "power_optimization"
            return 1
            ;;
        6)
            optimize_network_settings
            get_feature_status "network_optimization"
            return 1
            ;;
        7)
            flush_dns_cache
            get_feature_status "dns_flush"
            return 1
            ;;
        8)
            enable_firewall
            get_feature_status "firewall"
            return 1
            ;;
        9)
            clear_system_caches
            get_feature_status "cache_clear"
            return 1
            ;;
        10)
            remove_unused_languages
            get_feature_status "language_cleanup"
            return 1
            ;;
        11)
            clear_font_caches
            get_feature_status "font_cache"
            return 1
            ;;
        12)
            remove_ds_store_files
            get_feature_status "ds_store_cleanup"
            return 1
            ;;
        13)
            disable_spotlight
            get_feature_status "spotlight"
            return 1
            ;;
        14)
            disable_dashboard
            get_feature_status "dashboard"
            return 1
            ;;
        15)
            disable_animations
            get_feature_status "animations"
            return 1
            ;;
        16)
            optimize_dock
            get_feature_status "dock_optimization"
            return 1
            ;;
        17)
            verify_disk_permissions
            get_feature_status "disk_permissions"
            return 1
            ;;
        18)
            run_maintenance_scripts
            get_feature_status "maintenance_scripts"
            return 1
            ;;
        19)
            clear_system_logs
            get_feature_status "log_cleanup"
            return 1
            ;;
        20)
            reset_smc
            get_feature_status "smc_reset"
            return 1
            ;;
        21)
            show_all_statuses
            return 1
            ;;
        22)
            rm "$CONFIG_FILE"
            touch "$CONFIG_FILE"
            echo -e "${GREEN}All optimization states reset${NC}"
            return 1
            ;;
        23)
            toggle_power_saving
            get_feature_status "power_saving"
            return 1
            ;;
        24)
            check_system_status
            get_feature_status "system_check"
            return 1
            ;;
        0)
            echo -e "${GREEN}Quitting the script. Bye!${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
            return 1
            ;;
    esac
    
    # Add pause after each action
    if [ "$choice" != "0" ]; then
        echo -e "\nPress Enter to continue..."
        read
        return 1
    fi
} 
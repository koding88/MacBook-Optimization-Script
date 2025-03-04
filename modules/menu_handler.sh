#!/bin/bash

# Menu Handler Function

function handle_user_choice() {
    while true; do
        clear
        display_main_menu
        read -p "Enter your choice: " choice
        echo ""  # Add a blank line for better readability

        case $choice in
            1)
                optimize_system_performance
                get_feature_status "system_performance"
                ;;
            2)
                optimize_memory_management
                get_feature_status "memory_management"
                ;;
            3)
                optimize_ssd
                get_feature_status "ssd_optimization"
                ;;
            4)
                optimize_security
                get_feature_status "security_optimization"
                ;;
            5)
                optimize_power
                get_feature_status "power_optimization"
                ;;
            6)
                optimize_network_settings
                get_feature_status "network_optimization"
                ;;
            7)
                flush_dns_cache
                get_feature_status "dns_flush"
                ;;
            8)
                enable_firewall
                get_feature_status "firewall"
                ;;
            9)
                clear_system_caches
                get_feature_status "cache_clear"
                ;;
            10)
                remove_unused_languages
                get_feature_status "language_cleanup"
                ;;
            11)
                clear_font_caches
                get_feature_status "font_cache"
                ;;
            12)
                remove_ds_store_files
                get_feature_status "ds_store_cleanup"
                ;;
            13)
                disable_spotlight
                get_feature_status "spotlight"
                ;;
            14)
                disable_dashboard
                get_feature_status "dashboard"
                ;;
            15)
                disable_animations
                get_feature_status "animations"
                ;;
            16)
                optimize_dock
                get_feature_status "dock_optimization"
                ;;
            17)
                verify_disk_permissions
                get_feature_status "disk_permissions"
                ;;
            18)
                run_maintenance_scripts
                get_feature_status "maintenance_scripts"
                ;;
            19)
                clear_system_logs
                get_feature_status "log_cleanup"
                ;;
            20)
                reset_smc
                get_feature_status "smc_reset"
                ;;
            21)
                show_all_statuses
                ;;
            22)
                rm "$CONFIG_FILE"
                touch "$CONFIG_FILE"
                echo -e "${GREEN}All optimization states reset${NC}"
                ;;
            23)
                check_system_status
                get_feature_status "system_check"
                ;;
            24)
                toggle_power_saving
                get_feature_status "power_saving"
                ;;
            25)
                toggle_auto_boot
                get_feature_status "autoboot"
                ;;
            26)
                check_mdm_status
                ;;
            0)
                echo -e "${GREEN}Quitting the script. Bye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
                ;;
        esac
        
        # Add pause after each action
        if [ "$choice" != "0" ]; then
            echo -e "\nPress Enter to continue..."
            read
        fi
    done
} 
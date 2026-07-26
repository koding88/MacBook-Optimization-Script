#!/bin/bash

# ==============================================================================
# Module: menu_handler.sh
# Purpose: Handle user interaction and route choices to module functions
# ==============================================================================

function run_all_optimizations() {
    echo -e "${GREEN}=== Running All Safe System Optimizations ===${NC}"
    optimize_system_performance
    optimize_memory_management
    optimize_ssd
    optimize_security
    optimize_power
    optimize_network_settings
    flush_dns_cache
    enable_firewall
    clear_system_caches
    clear_font_caches
    disable_animations
    optimize_dock
    run_maintenance_scripts
    clear_system_logs
    terminate_zombie_processes
    run_system_benchmark
    echo -e "${GREEN}✓ All safe optimizations executed successfully.${NC}"
}

function handle_user_choice() {
    while true; do
        clear
        display_main_menu
        read -p "Enter your choice (0-34): " choice
        echo ""

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
                echo -e "${YELLOW}Resetting all optimization state tracking...${NC}"
                if [ -f "$CONFIG_FILE" ]; then
                    if rm -f "$CONFIG_FILE" 2>/dev/null; then
                        if initialize_config; then
                            echo -e "${GREEN}Optimization tracking state reset successfully.${NC}"
                        else
                            echo -e "${RED}Failed to recreate config file.${NC}"
                        fi
                    else
                        echo -e "${RED}Failed to remove config file.${NC}"
                    fi
                else
                    initialize_config
                    echo -e "${GREEN}New config state file created.${NC}"
                fi
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
            27)
                rollback_all_optimizations
                ;;
            28)
                if [ "$CURRENT_LANG" = "ES" ]; then
                    set_language "EN"
                    echo -e "${GREEN}Language switched to English.${NC}"
                else
                    set_language "ES"
                    echo -e "${GREEN}Idioma cambiado a Español.${NC}"
                fi
                ;;
            29)
                view_log_file
                ;;
            30)
                check_for_updates
                ;;
            31)
                run_parallel_diagnostics
                ;;
            32)
                check_thermal_status
                terminate_zombie_processes
                ;;
            33)
                run_system_benchmark
                ;;
            34)
                install_weekly_scheduler
                ;;
            0)
                echo -e "${GREEN}$(t "QUIT_MSG")${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}$(t "INVALID_CHOICE")${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "\n$(t "PRESS_ENTER")"
            read
        fi
    done
}
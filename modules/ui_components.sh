#!/bin/bash

# UI Components

function print_menu_item() {
    local number=$1
    local description=$2
    local feature_id=$3
    local padding=$4
    
    # Print menu item
    printf "%-${padding}s" "$number. $description"
    
    # Print status if feature_id is provided
    if [ ! -z "$feature_id" ]; then
        if grep -q "^$feature_id=" "$CONFIG_FILE"; then
            local line=$(grep "^$feature_id=" "$CONFIG_FILE" | tail -n 1)
            local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
            local timestamp=$(echo "$line" | cut -d'|' -f2)
            if [ "$status" = "enabled" ]; then
                echo -e "${GREEN}[ENABLED]${NC} $timestamp"
            else
                echo -e "${RED}[FAILED]${NC} $timestamp"
            fi
        else
            echo -e "${YELLOW}[NOT RUN]${NC}"
        fi
    else
        echo ""
    fi
}

function print_section_header() {
    local title=$1
    echo -e "\n${YELLOW}$title${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

function show_quick_summary() {
    echo -e "\n${BLUE}Quick Status Summary:${NC}"
    echo -e "${BLUE}------------------${NC}"
    local total=$(wc -l < "$CONFIG_FILE")
    local enabled=$(grep -c "=enabled|" "$CONFIG_FILE")
    local failed=$(grep -c "=failed|" "$CONFIG_FILE")
    echo -e "Total Optimizations Run: ${YELLOW}$total${NC}"
    echo -e "Successfully Enabled: ${GREEN}$enabled${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo -e "${BLUE}------------------${NC}"
}

function display_main_menu() {
    echo -e "${GREEN}=== MacBook Optimization Script ===${NC}"
    
    # Show quick status summary
    show_quick_summary

    # System Optimizations Section
    print_section_header "System Optimizations"
    print_menu_item "1" "Optimize System Performance" "system_performance" 45
    print_menu_item "2" "Optimize Memory Management" "memory_management" 45
    print_menu_item "3" "Optimize SSD Settings" "ssd_optimization" 45
    print_menu_item "4" "Optimize Security" "security_optimization" 45
    print_menu_item "5" "Optimize Power Settings" "power_optimization" 45

    # Network Optimizations Section
    print_section_header "Network Optimizations"
    print_menu_item "6" "Optimize Network Settings" "network_optimization" 45
    print_menu_item "7" "Flush DNS Cache" "dns_flush" 45
    print_menu_item "8" "Enable Network Firewall" "firewall" 45

    # Storage Optimizations Section
    print_section_header "Storage Optimizations"
    print_menu_item "9" "Clear System Caches" "cache_clear" 45
    print_menu_item "10" "Remove Unused Languages" "language_cleanup" 45
    print_menu_item "11" "Clear Font Caches" "font_cache" 45
    print_menu_item "12" "Remove .DS_Store Files" "ds_store_cleanup" 45

    # Performance Tweaks Section
    print_section_header "Performance Tweaks"
    print_menu_item "13" "Disable Spotlight Indexing" "spotlight" 45
    print_menu_item "14" "Disable Dashboard" "dashboard" 45
    print_menu_item "15" "Disable Animations" "animations" 45
    print_menu_item "16" "Optimize Dock" "dock_optimization" 45

    # Maintenance Section
    print_section_header "Maintenance"
    print_menu_item "17" "Verify Disk Permissions" "disk_permissions" 45
    print_menu_item "18" "Run Daily Maintenance Scripts" "maintenance_scripts" 45
    print_menu_item "19" "Clear System Logs" "log_cleanup" 45
    print_menu_item "20" "Reset SMC" "smc_reset" 45

    # System Monitoring Section
    print_section_header "System Monitoring and Status"
    print_menu_item "21" "View All Optimization States" "" 45
    print_menu_item "22" "Reset All Optimizations" "" 45
    print_menu_item "23" "Check System Status" "system_check" 45
    print_menu_item "24" "Toggle Power Saving Mode" "power_saving" 45
    print_menu_item "25" "Toggle AutoBoot (Intel Only)" "autoboot" 45
    print_menu_item "26" "Check MDM Status" "" 45

    echo -e "\n${BLUE}$(printf '=%.0s' {1..60})${NC}"
    print_menu_item "0" "Quit" "" 45
} 
#!/bin/bash

# ==============================================================================
# Module: ui_components.sh
# Purpose: UI rendering, i18n support, status tags, and menu layout
# ==============================================================================

function print_menu_item() {
    local number=$1
    local description=$2
    local feature_id=$3
    local padding=$4
    
    printf "%-${padding}s" "$number. $description"
    
    if [ -n "$feature_id" ]; then
        if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ] && grep -q "^$feature_id=" "$CONFIG_FILE" 2>/dev/null; then
            local line=$(grep "^$feature_id=" "$CONFIG_FILE" | tail -n 1)
            local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
            local timestamp=$(echo "$line" | cut -d'|' -f2)
            if [ "$status" = "enabled" ]; then
                echo -e "${GREEN}[$(t "ENABLED")]${NC} $timestamp"
            else
                echo -e "${RED}[$(t "FAILED")]${NC} $timestamp"
            fi
        else
            echo -e "${YELLOW}[$(t "NOT_RUN")]${NC}"
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
    local dry_tag=""
    if [ "$DRY_RUN" = true ]; then
        dry_tag="${RED} [DRY-RUN MODE ACTIVE]${NC}"
    fi

    local fs_upper=$(echo "$FILESYSTEM_TYPE" | tr '[:lower:]' '[:upper:]')

    echo -e "${BLUE}$(t "SYS_INFO"): macOS $OS_VERSION | $ARCH_NAME | APFS/HFS: $fs_upper | Lang: $CURRENT_LANG${NC}$dry_tag"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    
    if [ ! -f "$CONFIG_FILE" ] || [ ! -r "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Config state file not initialized.${NC}"
        echo -e "${BLUE}------------------${NC}"
        return 1
    fi
    
    local total=$(wc -l < "$CONFIG_FILE" 2>/dev/null || echo "0")
    local enabled=$(grep -c "=enabled|" "$CONFIG_FILE" 2>/dev/null || echo "0")
    local failed=$(grep -c "=failed|" "$CONFIG_FILE" 2>/dev/null || echo "0")
    echo -e "$(t "TOTAL_RUN"): ${YELLOW}$total${NC} | $(t "ENABLED"): ${GREEN}$enabled${NC} | $(t "FAILED"): ${RED}$failed${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

function display_main_menu() {
    echo -e "${GREEN}=== $(t "TITLE") (v3.1 Iterative Evolution) ===${NC}"
    
    show_quick_summary

    # System Optimizations Section
    print_section_header "$(t "SEC_SYS")"
    print_menu_item "1" "$(t "OPT_SYS_PERF")" "system_performance" 45
    print_menu_item "2" "$(t "OPT_MEM")" "memory_management" 45
    print_menu_item "3" "$(t "OPT_SSD")" "ssd_optimization" 45
    print_menu_item "4" "$(t "OPT_SEC")" "security_optimization" 45
    print_menu_item "5" "$(t "OPT_PWR")" "power_optimization" 45

    # Network Optimizations Section
    print_section_header "$(t "SEC_NET")"
    print_menu_item "6" "$(t "OPT_NET")" "network_optimization" 45
    print_menu_item "7" "$(t "OPT_DNS")" "dns_flush" 45
    print_menu_item "8" "$(t "OPT_FIREWALL")" "firewall" 45

    # Storage Optimizations Section
    print_section_header "$(t "SEC_STO")"
    print_menu_item "9" "$(t "OPT_CACHE")" "cache_clear" 45
    print_menu_item "10" "$(t "OPT_LANG_CLEAN")" "language_cleanup" 45
    print_menu_item "11" "$(t "OPT_FONT")" "font_cache" 45
    print_menu_item "12" "$(t "OPT_DS_STORE")" "ds_store_cleanup" 45

    # Performance Tweaks Section
    print_section_header "$(t "SEC_PERF")"
    print_menu_item "13" "$(t "OPT_SPOTLIGHT")" "spotlight" 45
    print_menu_item "14" "$(t "OPT_DASHBOARD")" "dashboard" 45
    print_menu_item "15" "$(t "OPT_ANIM")" "animations" 45
    print_menu_item "16" "$(t "OPT_DOCK")" "dock_optimization" 45

    # Maintenance Section
    print_section_header "$(t "SEC_MAINT")"
    print_menu_item "17" "$(t "OPT_DISK_PERM")" "disk_permissions" 45
    print_menu_item "18" "$(t "OPT_MAINT_SCRIPTS")" "maintenance_scripts" 45
    print_menu_item "19" "$(t "OPT_LOG_CLEAN")" "log_cleanup" 45
    print_menu_item "20" "$(t "OPT_SMC")" "smc_reset" 45

    # System Monitoring and Control Section
    print_section_header "$(t "SEC_MONITOR")"
    print_menu_item "21" "$(t "OPT_VIEW_ALL")" "" 45
    print_menu_item "22" "$(t "OPT_RESET_TRACKER")" "" 45
    print_menu_item "23" "$(t "OPT_SYS_CHECK")" "system_check" 45
    print_menu_item "24" "$(t "OPT_PWR_SAVING")" "power_saving" 45
    print_menu_item "25" "$(t "OPT_AUTOBOOT")" "autoboot" 45
    print_menu_item "26" "$(t "OPT_MDM")" "" 45
    print_menu_item "27" "$(t "OPT_ROLLBACK")" "" 45
    print_menu_item "28" "$(t "OPT_TOGGLE_LANG")" "" 45
    print_menu_item "29" "$(t "OPT_VIEW_LOGS")" "" 45
    print_menu_item "30" "Check for Updates" "" 45
    print_menu_item "31" "Run Parallel Hardware Diagnostics" "" 45
    print_menu_item "32" "Check Thermal Pressure & Rogue Processes" "zombie_cleanup" 45
    print_menu_item "33" "Run System Performance Benchmark Suite" "benchmark_suite" 45
    print_menu_item "34" "Install Automated Weekly Scheduler" "scheduler" 45

    echo -e "\n${BLUE}$(printf '=%.0s' {1..60})${NC}"
    print_menu_item "0" "$(t "OPT_QUIT")" "" 45
}
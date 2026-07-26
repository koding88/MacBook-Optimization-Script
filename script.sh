#!/bin/bash

# ==============================================================================
# MacBook Optimization Script - Entry Point (v3.1 Iterative Evolution)
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source all modular components
source "$SCRIPT_DIR/modules/trap_handler.sh"
source "$SCRIPT_DIR/modules/logger.sh"
source "$SCRIPT_DIR/modules/i18n.sh"
source "$SCRIPT_DIR/modules/json_engine.sh"
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/backup.sh"
source "$SCRIPT_DIR/modules/sys_compat.sh"
source "$SCRIPT_DIR/modules/rollback.sh"
source "$SCRIPT_DIR/modules/ui_library.sh"
source "$SCRIPT_DIR/modules/parallel_diag.sh"
source "$SCRIPT_DIR/modules/thermal_process.sh"
source "$SCRIPT_DIR/modules/benchmark.sh"
source "$SCRIPT_DIR/modules/scheduler.sh"
source "$SCRIPT_DIR/modules/plugin_loader.sh"
source "$SCRIPT_DIR/modules/updater.sh"
source "$SCRIPT_DIR/modules/ui_components.sh"
source "$SCRIPT_DIR/modules/system_optimizations.sh"
source "$SCRIPT_DIR/modules/network_optimizations.sh"
source "$SCRIPT_DIR/modules/storage_optimizations.sh"
source "$SCRIPT_DIR/modules/performance_tweaks.sh"
source "$SCRIPT_DIR/modules/maintenance.sh"
source "$SCRIPT_DIR/modules/system_monitoring.sh"
source "$SCRIPT_DIR/modules/power_management.sh"
source "$SCRIPT_DIR/modules/menu_handler.sh"

function show_help() {
    echo -e "${GREEN}MacBook Optimization Script v3.1 - Usage Guide${NC}"
    echo ""
    echo "Usage: ./script.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run          Simulate execution without modifying system settings."
    echo "  --all              Run all safe system optimizations automatically."
    echo "  --module <name>    Run specific module (system|network|storage|performance|maintenance|benchmark)."
    echo "  --status           Display non-interactive system status report."
    echo "  --rollback         Restore system settings to previous backup or defaults."
    echo "  --check-update     Check if a newer version of the script is available."
    echo "  --update           Update script from official git repository."
    echo "  --lang <es|en>     Set interface language (es: Spanish, en: English)."
    echo "  --help, -h         Show this help menu."
    echo ""
}

# Main script execution entry point
function main() {
    # Initialize Trap Handlers & Process Lock
    init_trap_handler
    acquire_lock
    load_plugins

    # Parse CLI Arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                echo -e "${YELLOW}[INFO] Dry-Run mode enabled. No system changes will be applied.${NC}"
                shift
                ;;
            --all)
                NON_INTERACTIVE=true
                detect_system_info
                initialize_config
                run_all_optimizations
                exit 0
                ;;
            --module)
                NON_INTERACTIVE=true
                detect_system_info
                initialize_config
                local mod_name="$2"
                shift 2
                case "$mod_name" in
                    system) optimize_system_performance; optimize_memory_management; optimize_ssd; optimize_security ;;
                    network) optimize_network_settings; flush_dns_cache; enable_firewall ;;
                    storage) clear_system_caches; clear_font_caches ;;
                    performance) disable_animations; optimize_dock ;;
                    maintenance) run_maintenance_scripts; clear_system_logs ;;
                    benchmark) run_system_benchmark ;;
                    *) echo -e "${RED}Unknown module name: $mod_name${NC}"; exit 1 ;;
                esac
                exit 0
                ;;
            --status)
                detect_system_info
                initialize_config
                print_system_summary
                show_all_statuses
                exit 0
                ;;
            --rollback)
                NON_INTERACTIVE=true
                detect_system_info
                initialize_config
                rollback_all_optimizations
                exit 0
                ;;
            --check-update)
                check_for_updates
                exit 0
                ;;
            --update)
                apply_update
                exit 0
                ;;
            --lang)
                set_language "$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown argument: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # Default Interactive Mode
    log_info "Launching v3.1 interactive session"
    detect_system_info
    initialize_config
    
    while true; do
        clear
        display_main_menu
        handle_user_choice
    done
}

# Start execution
main "$@"

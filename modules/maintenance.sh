#!/bin/bash

# ==============================================================================
# Module: maintenance.sh
# Purpose: Volume verification, system maintenance scripts, log cleanup, and SMC guidance
# ==============================================================================

function verify_disk_permissions() {
    echo -e "${BLUE}Verifying system disk volume integrity...${NC}"
    
    local status_code=0
    
    if [ "$FILESYSTEM_TYPE" = "apfs" ]; then
        echo -e "${YELLOW}Running APFS Volume Verification...${NC}"
        safe_exec sudo diskutil verifyVolume / 2>/dev/null || status_code=$?
    else
        echo -e "${YELLOW}Running HFS+ Volume Verification...${NC}"
        safe_exec sudo diskutil verifyVolume / 2>/dev/null || status_code=$?
    fi

    execute_task_status $status_code "Disk volume integrity verified" "disk_permissions"
}

function run_maintenance_scripts() {
    echo -e "${BLUE}Running macOS periodic maintenance scripts (daily, weekly, monthly)...${NC}"
    
    local status_code=0
    safe_exec sudo periodic daily weekly monthly 2>/dev/null || status_code=$?
    
    execute_task_status $status_code "Maintenance scripts executed" "maintenance_scripts"
}

function clear_system_logs() {
    echo -e "${BLUE}Clearing system log files...${NC}"
    
    safe_exec sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
    safe_exec sudo rm -rf /var/log/asl/*.asl 2>/dev/null
    
    execute_task_status 0 "System logs cleared" "log_cleanup"
}

function reset_smc() {
    echo -e "${BLUE}System Management Controller (SMC) Guidance${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    if [ "$IS_APPLE_SILICON" = true ]; then
        echo -e "${GREEN}Apple Silicon Mac detected (M1/M2/M3/M4):${NC}"
        echo "Apple Silicon Macs automatically reset System Management functions during restart."
        echo "1. Shut down your Mac."
        echo "2. Wait 30 seconds."
        echo "3. Press the power button to turn it back on."
    else
        echo -e "${YELLOW}Intel Mac detected:${NC}"
        echo "1. Shut down your MacBook."
        echo "2. Hold Shift + Control + Option (left side) and the Power button for 10 seconds."
        echo "3. Release all keys and power button."
        echo "4. Press the power button to turn on your MacBook."
    fi
    
    if [ "$NON_INTERACTIVE" != true ]; then
        read -p "Press Enter when done..."
    fi
    execute_task_status 0 "SMC reset instructions provided" "smc_reset"
}
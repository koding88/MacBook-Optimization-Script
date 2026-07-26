#!/bin/bash

# ==============================================================================
# Module: system_optimizations.sh
# Purpose: System performance, memory management, SSD, and security tuning
# ==============================================================================

function optimize_system_performance() {
    echo -e "${BLUE}Optimizing system kernel performance...${NC}"
    
    local errors=0
    
    # Backup current kernel limits before changing
    backup_setting "kern.ipc.somaxconn" "sysctl" "kern.ipc.somaxconn"
    backup_setting "kern.maxvnodes" "sysctl" "kern.maxvnodes"
    backup_setting "kern.maxproc" "sysctl" "kern.maxproc"
    backup_setting "kern.maxfiles" "sysctl" "kern.maxfiles"

    # Kernel IPC & File descriptor limits
    safe_exec sudo sysctl -w kern.ipc.somaxconn=2048 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w kern.maxvnodes=750000 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w kern.maxproc=2048 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w kern.maxfiles=200000 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w kern.maxfilesperproc=100000 2>/dev/null || ((errors++))

    # Network buffer clusters (only supported on certain macOS versions)
    safe_exec sudo sysctl -w kern.ipc.nmbclusters=65536 2>/dev/null || true

    execute_task_status $errors "System kernel performance optimized" "system_performance"
}

function optimize_memory_management() {
    echo -e "${BLUE}Optimizing memory management...${NC}"
    
    local status_code=0

    # Purge inactive RAM memory
    if command -v purge &>/dev/null; then
        safe_exec sudo purge 2>/dev/null || status_code=$?
    fi
    
    # Sudden Motion Sensor (SMS) - Only applicable to Intel Macs with hard drives
    if [ "$IS_INTEL" = true ]; then
        if pmset -g 2>/dev/null | grep -q "sms"; then
            backup_setting "sms" "pmset" "sms"
            echo -e "${YELLOW}Disabling Sudden Motion Sensor for SSD optimization...${NC}"
            safe_exec sudo pmset -a sms 0 2>/dev/null
        fi
    else
        echo -e "${GREEN}Apple Silicon detected: Sudden Motion Sensor disabled by design.${NC}"
    fi
    
    # Flush disk caches
    safe_exec sudo sync 2>/dev/null
    
    execute_task_status $status_code "Memory management optimized" "memory_management"
}

function optimize_ssd() {
    echo -e "${BLUE}Optimizing SSD settings...${NC}"
    
    backup_setting "hibernatemode" "pmset" "hibernatemode"

    # Disable hibernation mode (set to 0 for fast wake on SSD)
    safe_exec sudo pmset -a hibernatemode 0 2>/dev/null
    
    # Safe sleepimage cleanup if applicable and accessible
    if [ -f "/var/vm/sleepimage" ] && [ "$IS_SIP_ENABLED" = false ]; then
        safe_exec sudo rm -f /var/vm/sleepimage 2>/dev/null
    fi

    # Trimforce status / information
    echo -e "${YELLOW}Note: TRIM is enabled by default for Apple internal SSDs.${NC}"
    if [ "$NON_INTERACTIVE" != true ]; then
        read -p "Do you want to run 'trimforce enable' for third-party SSDs? (y/N): " run_trim
        if [[ $run_trim =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Executing trimforce (requires interactive confirmation)...${NC}"
            safe_exec sudo trimforce enable
        fi
    fi

    execute_task_status 0 "SSD settings optimized" "ssd_optimization"
}

function optimize_security() {
    echo -e "${BLUE}Optimizing security settings...${NC}"
    
    local errors=0

    backup_setting "globalstate" "/Library/Preferences/com.apple.alf" "globalstate"

    # Enable Application Layer Firewall (ALF)
    safe_exec sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1 2>/dev/null || ((errors++))
    safe_exec sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1 2>/dev/null || ((errors++))
    safe_exec sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1 2>/dev/null || ((errors++))
    
    execute_task_status $errors "Security settings optimized" "security_optimization"
}
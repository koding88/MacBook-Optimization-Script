#!/bin/bash

# ==============================================================================
# Module: network_optimizations.sh
# Purpose: TCP/IP stack tuning, DNS flushing, and firewall management
# ==============================================================================

function optimize_network_settings() {
    echo -e "${BLUE}Optimizing network stack settings...${NC}"
    
    backup_setting "net.inet.tcp.delayed_ack" "sysctl" "net.inet.tcp.delayed_ack"
    backup_setting "net.inet.tcp.blackhole" "sysctl" "net.inet.tcp.blackhole"

    local errors=0
    safe_exec sudo sysctl -w net.inet.tcp.delayed_ack=0 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w net.inet.tcp.blackhole=2 2>/dev/null || ((errors++))
    safe_exec sudo sysctl -w net.inet.tcp.path_mtu_discovery=1 2>/dev/null || ((errors++))
    
    # Optional / Deprecated OIDs on macOS 13+ Ventura/Sonoma
    safe_exec sudo sysctl -w net.inet.icmp.icmplim=50 2>/dev/null || true
    safe_exec sudo sysctl -w net.inet.tcp.mssdflt=1440 2>/dev/null || true

    execute_task_status $errors "Network stack optimized" "network_optimization"
}

function flush_dns_cache() {
    echo -e "${BLUE}Flushing DNS cache...${NC}"
    
    local status_code=0
    safe_exec sudo dscacheutil -flushcache 2>/dev/null || status_code=$?
    safe_exec sudo killall -HUP mDNSResponder 2>/dev/null || status_code=$?

    execute_task_status $status_code "DNS cache flushed" "dns_flush"
}

function enable_firewall() {
    echo -e "${BLUE}Enabling macOS Application Firewall...${NC}"
    
    local status_code=0
    if [ -x "/usr/libexec/ApplicationFirewall/socketfilterfw" ]; then
        safe_exec sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || status_code=$?
    else
        safe_exec sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1 2>/dev/null || status_code=$?
    fi

    execute_task_status $status_code "Network firewall enabled" "firewall"
}
#!/bin/bash

# Network Optimization Functions

function optimize_network_settings() {
    echo "Optimizing network settings..."
    
    # Enhanced network optimization commands
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440
    sudo sysctl -w net.inet.tcp.blackhole=2
    sudo sysctl -w net.inet.icmp.icmplim=50
    sudo sysctl -w net.inet.tcp.path_mtu_discovery=1
    sudo sysctl -w net.inet.tcp.tcp_keepalive=1

    check_status "Network settings optimized" "network_optimization"
}

function flush_dns_cache() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    check_status "DNS cache flushed" "dns_flush"
}

function enable_firewall() {
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    check_status "Network firewall enabled" "firewall"
} 
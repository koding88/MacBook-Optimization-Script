#!/bin/bash

# System Optimization Functions

function optimize_system_performance() {
    echo "Optimizing system performance..."
    
    # Enhanced system performance optimization
    sudo sysctl -w kern.ipc.somaxconn=2048
    sudo sysctl -w kern.ipc.nmbclusters=65536
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000

    check_status "System performance optimized" "system_performance"
}

function optimize_memory_management() {
    echo "Optimizing memory management..."
    
    # macOS memory optimization
    # Purge inactive memory
    sudo purge
    
    # Disable sudden motion sensor if it's a MacBook with HDD
    sudo pmset -a sms 0
    
    # Set memory pressure parameters
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000
    
    # Clear system caches
    sudo sync
    sudo purge
    
    check_status "Memory management optimized" "memory_management"
}

function optimize_ssd() {
    echo "Optimizing SSD settings..."
    
    # SSD optimizations 
    sudo trimforce enable
    sudo pmset -a hibernatemode 0
    sudo rm /var/vm/sleepimage
    
    check_status "SSD optimized" "ssd_optimization"
}

function optimize_security() {
    echo "Optimizing security settings..."
    
    # Security optimizations
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
    sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1
    
    check_status "Security settings optimized" "security_optimization"
} 
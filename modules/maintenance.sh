#!/bin/bash

# Maintenance Functions

function verify_disk_permissions() {
    sudo diskutil verifyPermissions /
    check_status "Disk permissions verified" "disk_permissions"
}

function run_maintenance_scripts() {
    sudo periodic daily weekly monthly
    check_status "Maintenance scripts executed" "maintenance_scripts"
}

function clear_system_logs() {
    sudo rm -rf /var/log/*
    check_status "System logs cleared" "log_cleanup"
}

function reset_smc() {
    echo "Please follow these steps to reset SMC:"
    echo "1. Shut down your MacBook"
    echo "2. Hold Shift + Control + Option and Power button for 10 seconds"
    echo "3. Release all keys and power button"
    echo "4. Press power button to turn on your MacBook"
    read -p "Press Enter when done..."
    check_status "SMC reset instructions provided" "smc_reset"
} 
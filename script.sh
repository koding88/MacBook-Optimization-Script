#!/bin/bash

function check_status() {
    if [ $? -eq 0 ]; then
        echo "Success: $1"
    else
        echo "Error: $1"
    fi
}

function optimize_network_settings() {
    echo "Optimizing network settings..."
    
    # Add your network optimization commands here
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440

    check_status "Network settings optimized"
}

function optimize_system_performance() {
    echo "Optimizing system performance..."
    
    # Add your system performance optimization commands here
    sudo sysctl -w kern.ipc.somaxconn=1024
    sudo sysctl -w kern.ipc.nmbclusters=32768

    check_status "System performance optimized"
}

while true; do
    echo "Choose an option:"
    echo "1. Disable spotlight indexing"
    echo "2. Disable sleepimage"
    echo "3. Disable App Nap"
    echo "4. Disable automatic termination of inactive apps"
    echo "5. Enable continuous disk checking"
    echo "6. Enable TRIM"
    echo "7. Enable lid wake"
    echo "8. Optimize swap usage"
    echo "9. Disable sudden motion sensor"
    echo "10. Disable hibernation and sleep"
    echo "11. Flush the DNS cache"
    echo "12. Optimize spotlight for faster searches"
    echo "13. Disable Dashboard"
    echo "14. Disable animations"
    echo "15. Disable local Time Machine snapshots"
    echo "16. Enable Secure Empty Trash"
    echo "17. Clear font caches"
    echo "18. Add command to remove .DS_Store files from new folders"
    echo "19. Optimize network settings"
    echo "20. Optimize system performance"
    echo "0. Quit"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            sudo mdutil -a -i off
            check_status "Spotlight indexing disabled"
            ;;
        2)
            sudo pmset -a hibernatemode 0
            check_status "Sleepimage disabled"
            ;;
        3)
            defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
            check_status "App Nap disabled"
            ;;
        4)
            defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES
            check_status "Automatic termination of inactive apps disabled"
            ;;
        5)
            sudo fsck -fy
            check_status "Continuous disk checking enabled"
            ;;
        6)
            sudo trimforce enable
            check_status "TRIM enabled"
            ;;
        7)
            sudo pmset -a lidwake 1
            check_status "Lid wake enabled"
            ;;
        8)
            sudo sysctl vm.swappiness=10
            check_status "Swap usage optimized"
            ;;
        9)
            sudo pmset -a sms 0
            check_status "Sudden motion sensor disabled"
            ;;
        10)
            sudo pmset -a hibernatemode 0
            sudo pmset -a sleep 0
            check_status "Hibernation and sleep disabled"
            ;;
        11)
            sudo dscacheutil -flushcache
            check_status "DNS cache flushed"
            ;;
        12)
            sudo mdutil -E /
            check_status "Spotlight optimized for faster searches"
            ;;
        13)
            defaults write com.apple.dashboard mcx-disabled -boolean YES && killall Dock
            check_status "Dashboard disabled"
            ;;
        14)
            defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
            defaults write -g QLPanelAnimationDuration -float 0
            defaults write com.apple.finder DisableAllAnimations -bool true
            check_status "Animations disabled"
            ;;
        15)
            sudo tmutil disablelocal
            check_status "Local Time Machine snapshots disabled"
            ;;
        16)
            defaults write com.apple.finder EmptyTrashSecurely -bool true
            check_status "Secure Empty Trash enabled"
            ;;
        17)
            sudo atsutil databases -remove
            check_status "Font caches cleared"
            ;;
        18)
            echo "Adding command to remove .DS_Store files from new folders"
            echo "find . -name '.DS_Store' -depth -exec rm {} \;" >> ~/.profile
            source ~/.profile
            check_status "Command added to remove .DS_Store files"
            ;;
        19)
            optimize_network_settings
            ;;
        20)
            optimize_system_performance
            ;;
        0)
            echo "Quitting the script. Bye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter a valid option."
            ;;
    esac
done

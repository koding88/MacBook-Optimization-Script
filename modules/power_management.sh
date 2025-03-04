#!/bin/bash

# Power Management Functions

function optimize_power() {
    echo "Optimizing power settings..."
    
    # Power management optimizations
    sudo pmset -a displaysleep 15
    sudo pmset -a disksleep 10
    sudo pmset -a womp 1
    sudo pmset -a networkoversleep 0
    
    check_status "Power settings optimized" "power_optimization"
}

function toggle_power_saving() {
    echo "Power Saving Mode Management..."
    
    # Get current power saving status
    local current_mode=$(pmset -g | grep lowpowermode | awk '{print $2}')
    
    if [ "$current_mode" = "1" ]; then
        # Disable power saving mode
        sudo pmset -a lowpowermode 0
        check_status "Power saving mode disabled" "power_saving"
    else
        # Enable power saving mode
        sudo pmset -a lowpowermode 1
        # Additional power saving optimizations
        sudo pmset -a displaysleep 5
        sudo pmset -a disksleep 5
        sudo pmset -a sleep 10
        sudo pmset -a lessbright 1
        sudo pmset -a halfdim 1
        check_status "Power saving mode enabled" "power_saving"
    fi
    
    # Show current power settings
    echo -e "\n${BLUE}Current Power Settings:${NC}"
    pmset -g
}

function toggle_auto_boot() {
    echo "AutoBoot Feature Management..."
    
    # Check if running on Intel Mac
    if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
        # Get current AutoBoot status (if possible)
        echo "Current AutoBoot status:"
        nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
        
        echo -e "\n1. Disable AutoBoot (prevent auto-start when opening lid)"
        echo "2. Enable AutoBoot (restore default behavior)"
        echo "3. Return to previous menu"
        
        read -p "Enter your choice (1-3): " choice
        
        case $choice in
            1)
                sudo nvram AutoBoot=%00
                check_status "AutoBoot disabled - Mac won't automatically start when opening lid" "autoboot"
                echo -e "\nNew AutoBoot status:"
                nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
                
                echo -e "\n${YELLOW}The changes require a system restart to take effect.${NC}"
                read -p "Would you like to restart now? (y/n): " restart_choice
                if [[ $restart_choice =~ ^[Yy]$ ]]; then
                    echo "System will restart in 5 seconds..."
                    sleep 5
                    sudo shutdown -r now
                else
                    echo "Please remember to restart your system later for changes to take effect."
                fi
                ;;
            2)
                sudo nvram AutoBoot=%03
                check_status "AutoBoot enabled - Mac will start when opening lid" "autoboot"
                echo -e "\nNew AutoBoot status:"
                nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
                
                echo -e "\n${YELLOW}The changes require a system restart to take effect.${NC}"
                read -p "Would you like to restart now? (y/n): " restart_choice
                if [[ $restart_choice =~ ^[Yy]$ ]]; then
                    echo "System will restart in 5 seconds..."
                    sleep 5
                    sudo shutdown -r now
                else
                    echo "Please remember to restart your system later for changes to take effect."
                fi
                ;;
            3)
                return
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    else
        echo "This feature is only available for Intel-based Macs."
        echo "Your Mac appears to be using Apple Silicon."
    fi
    
    read -p "Press Enter to continue..."
} 
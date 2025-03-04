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

function check_mdm_status() {
    echo -e "${YELLOW}Checking MDM (Mobile Device Management) Status...${NC}"
    echo "----------------------------------------"
    
    local mdm_detected=false
    local mdm_details=""
    
    # Check 1: Examine /etc/hosts for MDM blocking entries
    echo -e "\n${BLUE}Checking /etc/hosts for MDM entries:${NC}"
    if grep -q "deviceenrollment.apple.com\|mdmenrollment.apple.com\|iprofiles.apple.com" /etc/hosts; then
        echo -e "${RED}Found MDM blocking entries in /etc/hosts:${NC}"
        grep "deviceenrollment.apple.com\|mdmenrollment.apple.com\|iprofiles.apple.com" /etc/hosts
        mdm_detected=true
        mdm_details+="MDM blocking entries found in /etc/hosts\n"
    else
        echo -e "${GREEN}No MDM blocking entries found in /etc/hosts${NC}"
    fi
    
    # Check 2: Check enrollment profiles
    echo -e "\n${BLUE}Checking enrollment profiles:${NC}"
    local profile_output=$(sudo profiles show -type enrollment 2>&1)
    if [[ $profile_output == *"There are no enrollment profiles"* ]]; then
        echo -e "${GREEN}No enrollment profiles found${NC}"
    else
        echo -e "${RED}Enrollment profiles detected:${NC}"
        echo "$profile_output"
        mdm_detected=true
        mdm_details+="MDM enrollment profiles detected\n"
    fi
    
    # Summary
    echo -e "\n${YELLOW}MDM Status Summary:${NC}"
    if [ "$mdm_detected" = true ]; then
        echo -e "${RED}MDM Detection: POSITIVE${NC}"
        echo -e "Details:"
        echo -e "$mdm_details"
        echo -e "\nRecommendation: Your device appears to be under MDM control."
    else
        echo -e "${GREEN}MDM Detection: NEGATIVE${NC}"
        echo "Your device appears to be free from MDM control."
    fi
    
    read -p "Press Enter to continue..."
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
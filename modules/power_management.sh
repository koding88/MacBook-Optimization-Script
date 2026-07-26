#!/bin/bash

# ==============================================================================
# Module: power_management.sh
# Purpose: Power management, low power mode toggle, MDM status check, and AutoBoot
# ==============================================================================

function optimize_power() {
    echo -e "${BLUE}Optimizing power settings...${NC}"
    
    backup_setting "displaysleep" "pmset" "displaysleep"
    backup_setting "disksleep" "pmset" "disksleep"
    backup_setting "womp" "pmset" "womp"

    local errors=0
    safe_exec sudo pmset -a displaysleep 15 2>/dev/null || ((errors++))
    safe_exec sudo pmset -a disksleep 10 2>/dev/null || ((errors++))
    safe_exec sudo pmset -a womp 1 2>/dev/null || ((errors++))
    
    execute_task_status $errors "Power settings optimized" "power_optimization"
}

function toggle_power_saving() {
    echo -e "${BLUE}Power Saving Mode Management...${NC}"
    
    local current_mode=$(pmset -g 2>/dev/null | grep lowpowermode | awk '{print $2}')
    
    if [ "$current_mode" = "1" ]; then
        echo -e "${YELLOW}Disabling Low Power Mode...${NC}"
        safe_exec sudo pmset -a lowpowermode 0 2>/dev/null
        execute_task_status $? "Low power mode disabled" "power_saving"
    else
        echo -e "${GREEN}Enabling Low Power Mode...${NC}"
        safe_exec sudo pmset -a lowpowermode 1 2>/dev/null
        safe_exec sudo pmset -a displaysleep 5 2>/dev/null
        safe_exec sudo pmset -a disksleep 5 2>/dev/null
        execute_task_status $? "Low power mode enabled" "power_saving"
    fi
    
    echo -e "\n${BLUE}Current Power Settings:${NC}"
    pmset -g 2>/dev/null
}

function check_mdm_status() {
    echo -e "${YELLOW}Checking MDM (Mobile Device Management) Enrollment Status...${NC}"
    echo "--------------------------------------------------------"
    
    local mdm_detected=false
    local mdm_details=""
    
    # Check 1: Examine /etc/hosts for MDM blocking entries
    echo -e "\n${BLUE}[1/3] Checking /etc/hosts for MDM domain blocks:${NC}"
    if grep -qE "deviceenrollment.apple.com|mdmenrollment.apple.com|iprofiles.apple.com" /etc/hosts 2>/dev/null; then
        echo -e "${RED}Found MDM domain blocking entries in /etc/hosts:${NC}"
        grep -E "deviceenrollment.apple.com|mdmenrollment.apple.com|iprofiles.apple.com" /etc/hosts
        mdm_detected=true
        mdm_details+="• MDM blocking entries present in /etc/hosts\n"
    else
        echo -e "${GREEN}✓ No MDM domain blocks in /etc/hosts${NC}"
    fi
    
    # Check 2: Enrollment profiles via profiles command
    echo -e "\n${BLUE}[2/3] Checking Device Enrollment Profiles:${NC}"
    local profile_output=$(sudo profiles show -type enrollment 2>&1)
    local profile_status=$(sudo profiles status -type enrollment 2>&1)
    
    echo -e "$profile_status"
    
    if [[ $profile_output != *"There are no enrollment profiles"* && $profile_output != *"No enrollment"* && -n "$profile_output" ]]; then
        echo -e "${RED}Enrollment profiles detected:${NC}"
        echo "$profile_output"
        mdm_detected=true
        mdm_details+="• Device Enrollment profile active\n"
    else
        echo -e "${GREEN}✓ No enrollment profiles detected${NC}"
    fi
    
    # Check 3: Configuration Profiles database presence
    echo -e "\n${BLUE}[3/3] Checking Configuration Profiles Storage:${NC}"
    if [ -d "/var/db/ConfigurationProfiles/Settings" ] && [ "$(ls -A /var/db/ConfigurationProfiles/Settings 2>/dev/null)" ]; then
        echo -e "${YELLOW}Configuration Profiles directory contains active profiles.${NC}"
    else
        echo -e "${GREEN}✓ No custom configuration profiles installed.${NC}"
    fi

    # Summary
    echo -e "\n${YELLOW}=== MDM Status Final Summary ===${NC}"
    if [ "$mdm_detected" = true ]; then
        echo -e "${RED}MDM Detection: POSITIVE${NC}"
        echo -e "Details:"
        echo -e "$mdm_details"
    else
        echo -e "${GREEN}MDM Detection: NEGATIVE (Device is free from MDM control)${NC}"
    fi
    
    if [ "$NON_INTERACTIVE" != true ]; then
        read -p "Press Enter to continue..."
    fi
}

function toggle_auto_boot() {
    echo -e "${BLUE}AutoBoot Feature Management${NC}"
    
    if [ "$IS_INTEL" = true ]; then
        echo "Current NVRAM AutoBoot status:"
        nvram -p 2>/dev/null | grep "AutoBoot" || echo "AutoBoot nvram flag not set"
        
        if [ "$NON_INTERACTIVE" != true ]; then
            echo -e "\n1. Disable AutoBoot (prevent auto-start when opening lid)"
            echo "2. Enable AutoBoot (restore default behavior)"
            echo "3. Cancel"
            read -p "Enter choice (1-3): " choice
            
            case $choice in
                1)
                    safe_exec sudo nvram AutoBoot=%00
                    execute_task_status $? "AutoBoot disabled" "autoboot"
                    ;;
                2)
                    safe_exec sudo nvram AutoBoot=%03
                    execute_task_status $? "AutoBoot enabled" "autoboot"
                    ;;
                3)
                    return
                    ;;
                *)
                    echo "Invalid choice."
                    ;;
            esac
        fi
    else
        echo -e "${YELLOW}AutoBoot NVRAM configuration is exclusive to Intel-based Macs.${NC}"
        echo -e "${GREEN}On Apple Silicon ($ARCH_NAME), lid behavior is managed directly by the Secure Enclave.${NC}"
    fi
    
    if [ "$NON_INTERACTIVE" != true ]; then
        read -p "Press Enter to continue..."
    fi
}
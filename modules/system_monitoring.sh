#!/bin/bash

# Define Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Check Required Commands
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed. Please install it first.${NC}"
        exit 1
    fi
}

# Function to Display System Info
function display_system_info() {
    local info_type=$1
    
    echo -e "\n${BLUE}===== ${info_type^^} Information =====${NC}"
    
    case $info_type in
        "cpu")
            echo -e "${YELLOW}CPU Model:${NC} $(sysctl -n machdep.cpu.brand_string)"
            echo -e "${YELLOW}CPU Cores:${NC} $(sysctl -n hw.ncpu)"
            echo -e "${YELLOW}CPU Speed:${NC} $(sysctl -n hw.cpufrequency_max | awk '{print $1 / 1000000000 " GHz"}')"
            echo -e "\n${YELLOW}CPU Load:${NC}"
            top -l 1 | grep -E "^CPU"
            ;;
        "memory")
            echo -e "${YELLOW}Total RAM:${NC} $(sysctl -n hw.memsize | awk '{print $1 / 1024/1024/1024 " GB"}')"
            check_command perl
            vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^0-9]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
            ;;
        "gpu")
            system_profiler SPDisplaysDataType | grep -A 10 "Chipset Model"
            ;;
        "battery")
            pmset -g batt | grep -v "Now drawing from"
            system_profiler SPPowerDataType | grep -E "Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed"
            ;;
        "disk")
            echo -e "${YELLOW}Disk Space:${NC}"
            df -h / | awk 'NR==2{print "Used: " $3 " of " $2 " (" $5 " used)"}'
            ;;
        "network")
            echo -e "${YELLOW}Active Interfaces:${NC}"
            netstat -nr | grep default | awk '{print $NF}'
            ;;
        "temperature")
            if command -v istats &> /dev/null; then
                istats
            else
                echo -e "${RED}iStats not found! Installing iStats...${NC}"
                sudo gem install iStats
                istats
            fi
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose a valid system info category.${NC}"
            ;;
    esac
}

# Function for System Status Check
function check_system_status() {
    while true; do
        clear
        echo -e "${BLUE}=== System Status Menu ===${NC}"
        echo -e "${YELLOW}1.${NC} CPU Information"
        echo -e "${YELLOW}2.${NC} Memory Status"
        echo -e "${YELLOW}3.${NC} GPU Information"
        echo -e "${YELLOW}4.${NC} Battery Information"
        echo -e "${YELLOW}5.${NC} Disk Space"
        echo -e "${YELLOW}6.${NC} Network Status"
        echo -e "${YELLOW}7.${NC} Temperature Sensors"
        echo -e "${YELLOW}8.${NC} View All Information"
        echo -e "${YELLOW}0.${NC} Exit"

        read -p "Enter your choice (0-8): " info_choice
        
        case $info_choice in
            1) display_system_info "cpu" ;;
            2) display_system_info "memory" ;;
            3) display_system_info "gpu" ;;
            4) display_system_info "battery" ;;
            5) display_system_info "disk" ;;
            6) display_system_info "network" ;;
            7) display_system_info "temperature" ;;
            8)
                for type in "cpu" "memory" "gpu" "battery" "disk" "network" "temperature"; do
                    display_system_info "$type"
                    echo -e "\nPress Enter to continue..."
                    read
                done
                ;;
            0) echo -e "${GREEN}Exiting System Monitor.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 8.${NC}" ;;
        esac

        echo -e "\nPress Enter to return to the menu..."
        read
    done
}

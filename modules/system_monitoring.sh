#!/bin/bash

# ==============================================================================
# Module: system_monitoring.sh
# Purpose: Real-time hardware and system health diagnostics
# ==============================================================================

function display_system_info() {
    local info_type=$1
    
    case $info_type in
        "cpu")
            clear
            echo -e "\n${YELLOW}CPU Information:${NC}"
            echo -e "CPU Model : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
            echo -e "CPU Cores : $(sysctl -n hw.ncpu 2>/dev/null || echo "N/A")"
            if sysctl -n hw.cpufrequency_max &>/dev/null; then
                echo -e "CPU Speed : $(sysctl -n hw.cpufrequency_max | awk '{print $1 / 1000000000 " GHz"}')"
            fi
            echo -e "\n${BLUE}Current CPU Load:${NC}"
            top -l 1 | grep -E "^CPU"
            ;;
        "memory")
            clear
            echo -e "\n${YELLOW}Memory Status:${NC}"
            local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
            echo -e "Total RAM : $(awk "BEGIN {print $mem_bytes/1073741824}") GB"
            echo -e "\n${BLUE}Virtual Memory Statistics:${NC}"
            vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^0-9]+(\d+)/ and printf("%-20s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
            ;;
        "gpu")
            clear
            echo -e "\n${YELLOW}GPU Information:${NC}"
            system_profiler SPDisplaysDataType | grep -E "Chipset Model|VRAM|Vendor|Metal" || echo "GPU info not available"
            ;;
        "battery")
            clear
            echo -e "\n${YELLOW}Battery Information:${NC}"
            pmset -g batt | grep -v "Now drawing from"
            system_profiler SPPowerDataType 2>/dev/null | grep -E "Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed" || echo "Power profile not available"
            ;;
        "disk")
            clear
            echo -e "\n${YELLOW}Disk Space:${NC}"
            df -h / | tail -n 1 | awk '{print "Filesystem: " $1 "\nSize: " $2 "\nUsed: " $3 " (" $5 ")\nAvailable: " $4}'
            ;;
        "network")
            clear
            echo -e "\n${YELLOW}Network Interfaces:${NC}"
            ifconfig -l
            echo -e "\n${BLUE}Default Gateway:${NC}"
            netstat -nr | grep default | head -n 2
            ;;
        "temperature")
            clear
            echo -e "\n${YELLOW}Temperature Sensors:${NC}"
            if command -v istats &>/dev/null; then
                istats
            elif command -v osx-cpu-temp &>/dev/null; then
                osx-cpu-temp
            else
                echo -e "${YELLOW}iStats or osx-cpu-temp not installed.${NC}"
                echo -e "You can install iStats via: ${BLUE}sudo gem install iStats${NC}"
            fi
            ;;
    esac
}

function check_system_status() {
    while true; do
        clear
        echo -e "\n${BLUE}=== System Health & Hardware Diagnostics ===${NC}"
        echo -e "${BLUE}--------------------------------------------${NC}"
        echo -e "1. CPU Information"
        echo -e "2. Memory Status"
        echo -e "3. GPU Information"
        echo -e "4. Battery & Power Status"
        echo -e "5. Disk Space"
        echo -e "6. Network Status"
        echo -e "7. Temperature Sensors"
        echo -e "8. View All Information"
        echo -e "0. Back to Main Menu"
        
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
            0) return ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 8.${NC}" ;;
        esac
        
        if [ "$info_choice" != "0" ] && [ "$info_choice" != "8" ]; then
            echo -e "\nPress Enter to return to system status menu..."
            read
        fi
    done

    execute_task_status 0 "System status check completed" "system_check"
}
#!/bin/bash

# System Monitoring Functions

function display_system_info() {
    local info_type=$1
    
    case $info_type in
        "cpu")
            clear
            echo -e "\n${YELLOW}CPU Information:${NC}"
            echo -e "CPU Model: $(sysctl -n machdep.cpu.brand_string)"
            echo -e "CPU Cores: $(sysctl -n hw.ncpu)"
            echo -e "CPU Speed: $(sysctl -n hw.cpufrequency_max | awk '{print $1 / 1000000000 "GHz"}')"
            echo -e "\nCPU Load:"
            top -l 1 | grep -E "^CPU"
            ;;
        "memory")
            clear
            echo -e "\n${YELLOW}Memory Status:${NC}"
            echo -e "Total RAM: $(sysctl -n hw.memsize | awk '{print $1 / 1024/1024/1024 "GB"}')"
            vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^0-9]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
            ;;
        "gpu")
            clear
            echo -e "\n${YELLOW}GPU Information:${NC}"
            system_profiler SPDisplaysDataType | grep -A 10 "Chipset Model"
            ;;
        "battery")
            clear
            echo -e "\n${YELLOW}Battery Information:${NC}"
            pmset -g batt | grep -v "Now drawing from"
            system_profiler SPPowerDataType | grep -E "Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed"
            ;;
        "disk")
            clear
            echo -e "\n${YELLOW}Disk Space:${NC}"
            df -h / | tail -n 1 | awk '{print "Used: " $3 " of " $2 " (" $5 " used)"}'
            ;;
        "network")
            clear
            echo -e "\n${YELLOW}Network Status:${NC}"
            echo -e "Active Interfaces:"
            netstat -nr | grep default | awk '{print $NF}'
            ;;
        "temperature")
            clear
            echo -e "\n${YELLOW}Temperature Sensors:${NC}"
            if command -v istats &> /dev/null; then
                istats
            else
                echo "Installing iStats for temperature monitoring..."
                sudo gem install iStats
                istats
            fi
            ;;
    esac
}

function check_system_status() {
    while true; do
        clear
        echo -e "\n${BLUE}=== System Status Check ===${NC}"
        echo -e "${BLUE}------------------------${NC}"
        echo -e "\nChoose information to view:"
        echo -e "${YELLOW}1. CPU Information${NC}"
        echo -e "${YELLOW}2. Memory Status${NC}"
        echo -e "${YELLOW}3. GPU Information${NC}"
        echo -e "${YELLOW}4. Battery Information${NC}"
        echo -e "${YELLOW}5. Disk Space${NC}"
        echo -e "${YELLOW}6. Network Status${NC}"
        echo -e "${YELLOW}7. Temperature Sensors${NC}"
        echo -e "${YELLOW}8. View All Information${NC}"
        echo -e "${YELLOW}0. Back to Main Menu${NC}"
        
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

    check_status "System status check completed" "system_check"
} 
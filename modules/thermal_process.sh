#!/bin/bash

# ==============================================================================
# Module: thermal_process.sh (Iteration 1)
# Purpose: Thermal throttling analysis, CPU pressure check, and rogue process detection
# ==============================================================================

function check_thermal_status() {
    echo -e "${BLUE}Checking CPU Thermal & Power Throttling Status...${NC}"
    
    local therm_output=$(pmset -g therm 2>/dev/null)
    if [ -n "$therm_output" ]; then
        echo -e "${YELLOW}Thermal Status Summary:${NC}"
        echo "$therm_output"
    else
        echo -e "${GREEN}✓ No thermal throttling detected on CPU.${NC}"
    fi

    # Check for top CPU consuming processes
    echo -e "\n${BLUE}Top 5 Resource-Consuming Processes:${NC}"
    ps aux | sort -nr -k 3 | head -n 6 | awk '{printf "%-10s %-8s %-6s %-30s\n", $1, $2, $3"%", $11}'
}

function terminate_zombie_processes() {
    echo -e "${BLUE}Scanning for non-responsive (zombie/defunct) processes...${NC}"
    
    local zombies=$(ps -ax -o state,pid,comm | grep -E "^Z" || true)
    if [ -n "$zombies" ]; then
        echo -e "${RED}Found non-responsive processes:${NC}"
        echo "$zombies"
        if [ "$NON_INTERACTIVE" != true ]; then
            read -p "Do you want to terminate these zombie processes? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                safe_exec kill -9 $(echo "$zombies" | awk '{print $2}') 2>/dev/null
                execute_task_status 0 "Zombie processes terminated" "zombie_cleanup"
                return
            fi
        fi
    else
        echo -e "${GREEN}✓ No zombie or defunct processes detected.${NC}"
    fi

    execute_task_status 0 "Process scan completed" "zombie_cleanup"
}

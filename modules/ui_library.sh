#!/bin/bash

# ==============================================================================
# Module: ui_library.sh
# Purpose: Advanced CLI UI library (spinners, progress bars, table renderers)
# ==============================================================================

function show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    tput civis 2>/dev/null || true # Hide cursor
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    tput cnorm 2>/dev/null || true # Restore cursor
    printf "    \r"
}

function show_progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    printf "\r${BLUE}Progress: [${GREEN}"
    printf "%0.s█" $(seq 1 $filled 2>/dev/null || echo "")
    printf "%0.s░" $(seq 1 $empty 2>/dev/null || echo "")
    printf "${BLUE}] %3d%% (${current}/${total})${NC}" "$percent"
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

function render_table_header() {
    local col1_title="$1"
    local col2_title="$2"
    local col3_title="$3"

    printf "${YELLOW}+-%-25s-+-%-15s-+-%-20s-+${NC}\n" "-------------------------" "---------------" "--------------------"
    printf "${BLUE}| %-25s | %-15s | %-20s |${NC}\n" "$col1_title" "$col2_title" "$col3_title"
    printf "${YELLOW}+-%-25s-+-%-15s-+-%-20s-+${NC}\n" "-------------------------" "---------------" "--------------------"
}

function render_table_row() {
    local col1="$1"
    local col2="$2"
    local col3="$3"

    printf "| %-25s | %-15s | %-20s |\n" "$col1" "$col2" "$col3"
}

function render_table_footer() {
    printf "${YELLOW}+-%-25s-+-%-15s-+-%-20s-+${NC}\n" "-------------------------" "---------------" "--------------------"
}

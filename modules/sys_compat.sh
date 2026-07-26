#!/bin/bash

# ==============================================================================
# Module: sys_compat.sh
# Purpose: System detection and multi-OS/hardware compatibility for macOS
# ==============================================================================

# Global system environment variables
OS_NAME=""
OS_VERSION=""
OS_MAJOR_VERSION=0
OS_BUILD=""
ARCH_NAME=""
IS_APPLE_SILICON=false
IS_INTEL=false
IS_SSV_ENABLED=false
IS_SIP_ENABLED=false
FILESYSTEM_TYPE=""

function detect_system_info() {
    # 1. Detect Operating System
    OS_NAME=$(uname -s)
    if [ "$OS_NAME" != "Darwin" ]; then
        echo -e "${RED}Error: This script is intended for macOS (Darwin) only.${NC}"
        return 1
    fi

    # 2. Detect macOS Version
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "10.15.0")
    OS_BUILD=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    OS_MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d'.' -f1)

    # 3. Detect Architecture
    ARCH_NAME=$(uname -m)
    if [ "$ARCH_NAME" = "arm64" ]; then
        IS_APPLE_SILICON=true
        IS_INTEL=false
    else
        IS_APPLE_SILICON=false
        IS_INTEL=true
    fi

    # 4. Detect System Integrity Protection (SIP)
    if command -v csrutil &>/dev/null; then
        if csrutil status 2>/dev/null | grep -q "enabled"; then
            IS_SIP_ENABLED=true
        else
            IS_SIP_ENABLED=false
        fi
    fi

    # 5. Detect Signed System Volume (SSV) / Read-only /System (macOS 11+)
    if [ "$OS_MAJOR_VERSION" -ge 11 ]; then
        IS_SSV_ENABLED=true
    else
        IS_SSV_ENABLED=false
    fi

    # 6. Detect Root Filesystem Type
    FILESYSTEM_TYPE=$(df -T / 2>/dev/null | tail -n 1 | awk '{print $2}' || echo "apfs")
    if [ -z "$FILESYSTEM_TYPE" ] || [ "$FILESYSTEM_TYPE" = "/" ]; then
        if mount | grep "on / " | grep -q "apfs"; then
            FILESYSTEM_TYPE="apfs"
        else
            FILESYSTEM_TYPE="hfs"
        fi
    fi

    return 0
}

function print_system_summary() {
    local fs_upper=$(echo "$FILESYSTEM_TYPE" | tr '[:lower:]' '[:upper:]')
    echo -e "${BLUE}=== System Detection Summary ===${NC}"
    echo -e "macOS Version : ${YELLOW}macOS $OS_VERSION (Build $OS_BUILD)${NC}"
    if [ "$IS_APPLE_SILICON" = true ]; then
        echo -e "Architecture  : ${GREEN}Apple Silicon ($ARCH_NAME)${NC}"
    else
        echo -e "Architecture  : ${YELLOW}Intel ($ARCH_NAME)${NC}"
    fi
    echo -e "Filesystem    : ${YELLOW}$fs_upper${NC}"
    echo -e "SIP Status    : $( [ "$IS_SIP_ENABLED" = true ] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}" )"
    echo -e "SSV Active    : $( [ "$IS_SSV_ENABLED" = true ] && echo -e "${GREEN}Yes (Read-Only /System)${NC}" || echo -e "${YELLOW}No${NC}" )"
    echo -e "${BLUE}================================${NC}"
}

# Check if a command is available on current system
function is_command_available() {
    command -v "$1" &>/dev/null
}

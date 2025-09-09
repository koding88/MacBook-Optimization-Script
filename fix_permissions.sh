#!/bin/bash

# MacBook Optimization Script - Permission Fix Utility
# This script fixes common permission issues with the .macbook_optimizer_state.conf file

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_FILE="$HOME/.macbook_optimizer_state.conf"

echo -e "${BLUE}MacBook Optimization Script - Permission Fix Utility${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

echo -e "${YELLOW}Checking configuration file: $CONFIG_FILE${NC}"

# Check if file exists
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Config file exists${NC}"
    
    # Check current permissions
    CURRENT_PERMS=$(stat -f "%Mp%Lp" "$CONFIG_FILE" 2>/dev/null || ls -l "$CONFIG_FILE" | cut -d' ' -f1)
    echo -e "${BLUE}Current permissions: $CURRENT_PERMS${NC}"
    
    # Check if readable
    if [ -r "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ File is readable${NC}"
    else
        echo -e "${RED}✗ File is not readable${NC}"
    fi
    
    # Check if writable
    if [ -w "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ File is writable${NC}"
        echo -e "${GREEN}No permission fixes needed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ File is not writable${NC}"
    fi
    
    # Attempt to fix permissions
    echo ""
    echo -e "${YELLOW}Attempting to fix permissions...${NC}"
    
    if chmod 644 "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully fixed file permissions${NC}"
        
        # Verify fix
        if [ -w "$CONFIG_FILE" ]; then
            echo -e "${GREEN}✓ File is now writable${NC}"
            echo -e "${GREEN}Permission issue resolved!${NC}"
        else
            echo -e "${RED}✗ File is still not writable after permission change${NC}"
            echo -e "${YELLOW}This might be due to file system or ownership issues${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to change file permissions${NC}"
        echo -e "${YELLOW}You may need to run: sudo chown $USER:$(id -gn) \"$CONFIG_FILE\"${NC}"
    fi
    
else
    echo -e "${YELLOW}Config file doesn't exist${NC}"
    echo -e "${YELLOW}Attempting to create it...${NC}"
    
    # Try to create the file
    if touch "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully created config file${NC}"
        
        # Set proper permissions
        if chmod 644 "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ Set proper permissions (644)${NC}"
            echo -e "${GREEN}Config file ready!${NC}"
        else
            echo -e "${YELLOW}⚠ Created file but couldn't set permissions${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to create config file${NC}"
        echo -e "${YELLOW}Please check your home directory permissions${NC}"
        
        # Check home directory permissions
        if [ -w "$HOME" ]; then
            echo -e "${GREEN}✓ Home directory is writable${NC}"
        else
            echo -e "${RED}✗ Home directory is not writable${NC}"
            echo -e "${YELLOW}This is likely the root cause of the issue${NC}"
        fi
    fi
fi

echo ""
echo -e "${BLUE}Diagnostic Information:${NC}"
echo -e "${BLUE}======================${NC}"
echo -e "Config file path: $CONFIG_FILE"
echo -e "Home directory: $HOME"
echo -e "Current user: $(whoami)"
echo -e "User ID: $(id -u)"
echo -e "Group ID: $(id -g)"
echo -e "Home directory permissions: $(ls -ld "$HOME" | cut -d' ' -f1)"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "Config file owner: $(ls -l "$CONFIG_FILE" | awk '{print $3":"$4}')"
    echo -e "Config file permissions: $(ls -l "$CONFIG_FILE" | cut -d' ' -f1)"
fi

echo ""
echo -e "${YELLOW}If issues persist, try:${NC}"
echo -e "1. ${BLUE}rm \"$CONFIG_FILE\" && touch \"$CONFIG_FILE\" && chmod 644 \"$CONFIG_FILE\"${NC}"
echo -e "2. ${BLUE}sudo chown \$USER:\$(id -gn) \"$CONFIG_FILE\"${NC}"
echo -e "3. Check if your home directory has proper permissions"
echo ""

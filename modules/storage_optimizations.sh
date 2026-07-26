#!/bin/bash

# ==============================================================================
# Module: storage_optimizations.sh
# Purpose: System cache cleanup, font cache reset, and DS_Store file removal
# ==============================================================================

function clear_system_caches() {
    echo -e "${BLUE}Clearing system and user caches...${NC}"
    
    safe_exec rm -rf "$HOME/Library/Caches"/* 2>/dev/null
    safe_exec sudo rm -rf /Library/Caches/* 2>/dev/null

    execute_task_status 0 "System caches cleared" "cache_clear"
}

function remove_unused_languages() {
    echo -e "${BLUE}Checking unused language cleanup compatibility...${NC}"
    
    if [ "$IS_SSV_ENABLED" = true ]; then
        echo -e "${YELLOW}Notice: macOS $OS_VERSION uses Signed System Volume (SSV).${NC}"
        echo -e "${YELLOW}System localization files in /System are protected read-only by Apple.${NC}"
        echo -e "${GREEN}Skipping system file modification to maintain OS integrity.${NC}"
        execute_task_status 0 "Language cleanup (SSV Protected - Skipped)" "language_cleanup"
        return 0
    fi

    if [ -d "/System/Library/CoreServices/Language Chooser.app" ]; then
        safe_exec sudo rm -rf "/System/Library/CoreServices/Language Chooser.app" 2>/dev/null
        execute_task_status $? "Unused languages removed" "language_cleanup"
    else
        execute_task_status 0 "No language chooser files to clean" "language_cleanup"
    fi
}

function clear_font_caches() {
    echo -e "${BLUE}Clearing font caches...${NC}"
    
    local status_code=0
    
    if is_command_available "atsutil"; then
        safe_exec sudo atsutil databases -remove 2>/dev/null || status_code=$?
        safe_exec sudo atsutil server -shutdown 2>/dev/null
        safe_exec sudo atsutil server -ping 2>/dev/null
    else
        echo -e "${YELLOW}atsutil not available in macOS $OS_VERSION. Clearing user font caches directly...${NC}"
        safe_exec rm -rf "$HOME/Library/Caches/com.apple.FontRegistry" 2>/dev/null
        safe_exec sudo rm -rf /Library/Caches/com.apple.ATS/* 2>/dev/null
    fi

    execute_task_status $status_code "Font caches cleared" "font_cache"
}

function remove_ds_store_files() {
    echo -e "${BLUE}Removing .DS_Store files...${NC}"
    
    local target_dir="."
    if [ "$NON_INTERACTIVE" != true ]; then
        echo "Select target directory:"
        echo "1. Current Directory ($(pwd))"
        echo "2. User Home Directory ($HOME)"
        read -p "Choice (1-2, default 1): " dir_choice
        
        if [ "$dir_choice" = "2" ]; then
            target_dir="$HOME"
        fi
    fi

    echo -e "${YELLOW}Searching and removing .DS_Store files in $target_dir...${NC}"
    safe_exec find "$target_dir" -name '.DS_Store' -depth -exec rm -f {} \; 2>/dev/null

    execute_task_status 0 ".DS_Store files removed from $target_dir" "ds_store_cleanup"
}
#!/bin/bash

# Storage Optimization Functions

function clear_system_caches() {
    sudo rm -rf ~/Library/Caches/*
    sudo rm -rf /Library/Caches/*
    check_status "System caches cleared" "cache_clear"
}

function remove_unused_languages() {
    sudo rm -rf /System/Library/CoreServices/Language\ Chooser.app
    check_status "Unused languages removed" "language_cleanup"
}

function clear_font_caches() {
    sudo atsutil databases -remove
    sudo atsutil server -shutdown
    sudo atsutil server -ping
    check_status "Font caches cleared" "font_cache"
}

function remove_ds_store_files() {
    find . -name '.DS_Store' -depth -exec rm {} \;
    check_status "DS_Store files removed" "ds_store_cleanup"
} 
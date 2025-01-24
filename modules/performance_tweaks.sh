#!/bin/bash

# Performance Optimization Functions

function disable_spotlight() {
    sudo mdutil -a -i off
    check_status "Spotlight indexing disabled" "spotlight"
}

function disable_dashboard() {
    defaults write com.apple.dashboard mcx-disabled -boolean YES
    killall Dock
    check_status "Dashboard disabled" "dashboard"
}

function disable_animations() {
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.dock launchanim -bool false
    killall Dock
    check_status "Animations disabled" "animations"
}

function optimize_dock() {
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0
    defaults write com.apple.dock springboard-show-duration -int 0
    defaults write com.apple.dock springboard-hide-duration -int 0
    killall Dock
    check_status "Dock animations disabled" "dock_optimization"
} 
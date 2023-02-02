#!/bin/bash

# Disable spotlight indexing
sudo mdutil -a -i off

# Disable sleepimage to save disk space
sudo pmset -a hibernatemode 0

# Disable App Nap
defaults write NSGlobalDomain NSAppSleepDisabled -bool YES

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES

# Enable continuous disk checking
sudo fsck -fy

# Enable TRIM
sudo trimforce enable

# Enable lid wake
sudo pmset -a lidwake 1

# Optimize swap usage
sudo sysctl vm.swappiness=10

# Disable the sudden motion sensor
sudo pmset -a sms 0

# Disable hibernation and sleep
sudo pmset -a hibernatemode 0
sudo pmset -a sleep 0

# Flush the DNS cache
sudo dscacheutil -flushcache

# Optimize spotlight for faster searches
sudo mdutil -E /

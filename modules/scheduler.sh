#!/bin/bash

# ==============================================================================
# Module: scheduler.sh (Iteration 3)
# Purpose: macOS LaunchAgent scheduler for automated weekly maintenance
# ==============================================================================

PLIST_PATH="$HOME/Library/LaunchAgents/com.koding88.macbook-optimizer.plist"

function install_weekly_scheduler() {
    echo -e "${BLUE}Installing macOS LaunchAgent for automated weekly maintenance...${NC}"
    
    mkdir -p "$HOME/Library/LaunchAgents" 2>/dev/null
    
    cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.koding88.macbook-optimizer</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/script.sh</string>
        <string>--all</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

    if is_command_available "launchctl"; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH" 2>/dev/null
        echo -e "${GREEN}✓ Automated weekly background optimization schedule installed (Every Monday at 3:00 AM).${NC}"
        execute_task_status 0 "Weekly LaunchAgent installed" "scheduler"
    else
        execute_task_status 1 "launchctl command not available" "scheduler"
    fi
}

function uninstall_weekly_scheduler() {
    echo -e "${YELLOW}Uninstalling weekly background optimization schedule...${NC}"
    
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH" 2>/dev/null
        echo -e "${GREEN}✓ Weekly schedule uninstalled.${NC}"
        execute_task_status 0 "Weekly LaunchAgent uninstalled" "scheduler"
    else
        echo -e "${YELLOW}No schedule installed to remove.${NC}"
    fi
}

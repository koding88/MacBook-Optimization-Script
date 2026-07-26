#!/bin/bash

# ==============================================================================
# Module: backup.sh
# Purpose: Backup user defaults and power settings before applying tweaks,
#          enabling exact state restoration during rollback.
# ==============================================================================

BACKUP_FILE="$HOME/.macbook_optimizer_user_backup.conf"

function backup_setting() {
    local key="$1"
    local domain="$2"
    local pref_key="$3"
    
    local value=""
    if [ "$domain" = "pmset" ]; then
        value=$(pmset -g 2>/dev/null | grep "$pref_key" | awk '{print $2}')
    elif [ "$domain" = "sysctl" ]; then
        value=$(sysctl -n "$pref_key" 2>/dev/null)
    else
        value=$(defaults read "$domain" "$pref_key" 2>/dev/null)
    fi

    if [ -n "$value" ]; then
        # Ensure file exists
        touch "$BACKUP_FILE" 2>/dev/null
        # Save if not already saved
        if ! grep -q "^$key=" "$BACKUP_FILE" 2>/dev/null; then
            echo "$key=$domain|$pref_key|$value" >> "$BACKUP_FILE" 2>/dev/null
            log_info "Backup created: $key = $value ($domain $pref_key)"
        fi
    fi
}

function restore_from_backup() {
    if [ ! -f "$BACKUP_FILE" ] || [ ! -r "$BACKUP_FILE" ]; then
        return 1
    fi

    echo -e "${YELLOW}Restoring settings from user backup ($BACKUP_FILE)...${NC}"
    log_info "Restoring settings from backup file $BACKUP_FILE"

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local key=$(echo "$line" | cut -d'=' -f1)
            local rest=$(echo "$line" | cut -d'=' -f2-)
            local domain=$(echo "$rest" | cut -d'|' -f1)
            local pref_key=$(echo "$rest" | cut -d'|' -f2)
            local val=$(echo "$rest" | cut -d'|' -f3)

            if [ "$domain" = "pmset" ]; then
                sudo pmset -a "$pref_key" "$val" 2>/dev/null
            elif [ "$domain" = "sysctl" ]; then
                sudo sysctl -w "$pref_key=$val" 2>/dev/null
            else
                defaults write "$domain" "$pref_key" "$val" 2>/dev/null
            fi
            echo -e "${GREEN}✓ Restored $pref_key to original value ($val)${NC}"
        fi
    done < "$BACKUP_FILE"

    rm -f "$BACKUP_FILE" 2>/dev/null
    return 0
}

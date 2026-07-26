#!/bin/bash

# ==============================================================================
# Module: trap_handler.sh
# Purpose: Graceful signal handling, terminal cleanup, and trap handlers
# ==============================================================================

# Lock file to prevent concurrent execution instances
LOCK_FILE="/tmp/macbook_optimizer.lock"

function init_trap_handler() {
    # Register trap signals
    trap cleanup_on_exit EXIT
    trap handle_interrupt SIGINT SIGTERM
}

function acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo -e "${RED}Error: Another instance of MacBook Optimization Script (PID $pid) is already running.${NC}"
            exit 1
        fi
    fi
    echo "$$" > "$LOCK_FILE" 2>/dev/null
}

function release_lock() {
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE" 2>/dev/null
    fi
}

function cleanup_on_exit() {
    # Restore terminal cursor & color settings
    tput cnorm 2>/dev/null || true
    echo -e "${NC}" 2>/dev/null || true
    release_lock
}

function handle_interrupt() {
    echo -e "\n\n${YELLOW}[!] Interrupt signal received (Ctrl+C). Cleaning up...${NC}"
    log_warn "Process interrupted by user signal (SIGINT/SIGTERM)"
    cleanup_on_exit
    exit 130
}

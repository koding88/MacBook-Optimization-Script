#!/bin/bash

# ==============================================================================
# Module: parallel_diag.sh
# Purpose: Concurrent parallel background diagnostics engine
# ==============================================================================

DIAG_TMP_DIR="/tmp/mbo_diag_$$"

function run_parallel_diagnostics() {
    echo -e "${BLUE}Running concurrent parallel system diagnostics...${NC}"
    mkdir -p "$DIAG_TMP_DIR" 2>/dev/null

    # 1. CPU Diag in background
    (
        echo "CPU Model: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)" > "$DIAG_TMP_DIR/cpu.txt"
        echo "CPU Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo "N/A")" >> "$DIAG_TMP_DIR/cpu.txt"
    ) &

    # 2. RAM Diag in background
    (
        local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        echo "Total RAM: $(awk "BEGIN {print $mem_bytes/1073741824}") GB" > "$DIAG_TMP_DIR/mem.txt"
    ) &

    # 3. Disk Diag in background
    (
        df -h / | tail -n 1 | awk '{print "Used: " $3 " / Total: " $2 " (" $5 " Used)"}' > "$DIAG_TMP_DIR/disk.txt"
    ) &

    # 4. Battery Diag in background
    (
        pmset -g batt 2>/dev/null | grep -v "Now drawing from" > "$DIAG_TMP_DIR/battery.txt"
    ) &

    # Wait for all background diagnostic jobs to complete
    wait

    # Print summary
    echo -e "${GREEN}✓ Diagnostic Results (Parallel Fetch Complete):${NC}"
    [ -f "$DIAG_TMP_DIR/cpu.txt" ] && cat "$DIAG_TMP_DIR/cpu.txt"
    [ -f "$DIAG_TMP_DIR/mem.txt" ] && cat "$DIAG_TMP_DIR/mem.txt"
    [ -f "$DIAG_TMP_DIR/disk.txt" ] && cat "$DIAG_TMP_DIR/disk.txt"
    [ -f "$DIAG_TMP_DIR/battery.txt" ] && cat "$DIAG_TMP_DIR/battery.txt"

    rm -rf "$DIAG_TMP_DIR" 2>/dev/null
}

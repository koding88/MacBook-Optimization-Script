#!/bin/bash

# ==============================================================================
# Integration Test Suite for MacBook Optimization Script v3.1
# ==============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
PASSED=0
FAILED=0

function assert_success() {
    local test_name="$1"
    shift
    echo -n "Testing: $test_name ... "
    if "$@" >/dev/null 2>&1; then
        echo -e "\033[0;32m[PASS]\033[0m"
        ((PASSED++))
    else
        echo -e "\033[0;31m[FAIL]\033[0m"
        ((FAILED++))
    fi
}

echo "=================================================="
echo "Running MacBook Optimization Script v3.1 Test Suite"
echo "=================================================="

# Test 1: Syntax check of all scripts
assert_success "Bash syntax check" bash -n "$SCRIPT_DIR"/script.sh "$SCRIPT_DIR"/fix_permissions.sh "$SCRIPT_DIR"/modules/*.sh

# Test 2: Help flag
assert_success "CLI argument --help" "$SCRIPT_DIR"/script.sh --help

# Test 3: Status flag (non-interactive)
assert_success "CLI argument --status" "$SCRIPT_DIR"/script.sh --status

# Test 4: Dry-Run mode simulation
assert_success "CLI argument --dry-run --module performance" "$SCRIPT_DIR"/script.sh --dry-run --module performance

# Test 5: System detection execution
assert_success "System detection execution" bash -c "source '$SCRIPT_DIR'/modules/config.sh; source '$SCRIPT_DIR'/modules/sys_compat.sh; detect_system_info"

# Test 6: Parallel Diagnostics Engine
assert_success "Parallel diagnostics engine" bash -c "source '$SCRIPT_DIR'/modules/config.sh; source '$SCRIPT_DIR'/modules/parallel_diag.sh; run_parallel_diagnostics"

# Test 7: Benchmark suite execution
assert_success "Benchmark suite module" "$SCRIPT_DIR"/script.sh --module benchmark

# Test 8: Update check
assert_success "Update checker flag --check-update" "$SCRIPT_DIR"/script.sh --check-update

# Summary
echo "=================================================="
echo -e "Test Results: \033[0;32m$PASSED Passed\033[0m, \033[0;31m$FAILED Failed\033[0m"
echo "=================================================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0

#!/bin/bash

# Core functionality tests for bash freezing fixes
# Tests each PM script with real files and directories

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/ccpm-test-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../.claude/scripts/pm" && pwd)"
MONITORING_SCRIPT="$(cd "$(dirname "$0")/../../.claude/scripts" && pwd)/monitor.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup test environment
setup_test_env() {
    echo "Setting up test environment in $TEST_DIR..."
    mkdir -p "$TEST_DIR/.claude/prds"
    mkdir -p "$TEST_DIR/.claude/epics"
    cd "$TEST_DIR"
}

# Create test files
create_test_files() {
    local count=$1
    local type=$2

    case "$type" in
        "prd")
            for i in $(seq 1 "$count"); do
                cat > ".claude/prds/test-prd-$i.md" <<EOF
name: Test PRD $i
status: backlog
description: Test PRD number $i
EOF
            done
            ;;
        "epic")
            for i in $(seq 1 "$count"); do
                mkdir -p ".claude/epics/test-epic-$i"
                cat > ".claude/epics/test-epic-$i/epic.md" <<EOF
name: Test Epic $i
status: open
description: Test Epic number $i
EOF
            done
            ;;
        "task")
            for epic in .claude/epics/*/; do
                [ -d "$epic" ] || continue
                for i in $(seq 1 "$count"); do
                    cat > "$epic/$i.md" <<EOF
name: Test Task $i
status: open
priority: medium
depends_on: []
EOF
                done
            done
            ;;
    esac
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit="$3"

    echo -n "Testing $test_name... "

    # Run with monitoring
    local start_time=$(date +%s)
    local output
    local exit_code=0

    # Start monitor in background
    "$MONITORING_SCRIPT" $$ 1 5 "/tmp/monitor-$$.log" >/dev/null 2>&1 &
    local monitor_pid=$!

    # Run the test
    if output=$($test_command 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # Stop monitor
    kill "$monitor_pid" 2>/dev/null || true

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Check results
    if [ "$exit_code" -eq "$expected_exit" ]; then
        echo -e "${GREEN}PASSED${NC} (${duration}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Check for zombie processes
        local zombies=$(ps aux | grep " Z " | grep -v grep | wc -l)
        if [ "$zombies" -gt 0 ]; then
            echo -e "  ${YELLOW}WARNING: $zombies zombie processes detected${NC}"
        fi

        return 0
    else
        echo -e "${RED}FAILED${NC} (exit: $exit_code, expected: $expected_exit)"
        echo "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test each script with various file counts
test_with_file_count() {
    local script="$1"
    local file_count="$2"

    echo ""
    echo "=== Testing $script with $file_count files ==="

    # Setup clean environment
    rm -rf "$TEST_DIR"
    setup_test_env

    # Create test files
    create_test_files "$file_count" "prd"
    create_test_files "$file_count" "epic"
    create_test_files 5 "task"  # Always create some tasks

    # Run the script
    run_test "$script ($file_count files)" "$SCRIPT_DIR/$script" 0
}

# Main test execution
echo "=== CCPM Bash Freezing Core Tests ==="
echo "Testing directory: $TEST_DIR"
echo "Script directory: $SCRIPT_DIR"
echo ""

setup_test_env

# Test 1: Empty directories
echo "=== Test 1: Empty Directories ==="
run_test "status.sh (empty)" "$SCRIPT_DIR/status.sh" 0
run_test "standup.sh (empty)" "$SCRIPT_DIR/standup.sh" 0
run_test "blocked.sh (empty)" "$SCRIPT_DIR/blocked.sh" 0
run_test "next.sh (empty)" "$SCRIPT_DIR/next.sh" 0

# Test 2: Small file count (10 files)
test_with_file_count "status.sh" 10
test_with_file_count "standup.sh" 10
test_with_file_count "blocked.sh" 10

# Test 3: Medium file count (100 files)
test_with_file_count "status.sh" 100
test_with_file_count "standup.sh" 100

# Test 4: Search functionality
echo ""
echo "=== Test 4: Search Functionality ==="
create_test_files 50 "prd"
create_test_files 20 "epic"
run_test "search.sh" "$SCRIPT_DIR/search.sh 'test'" 0

# Test 5: Process limits
echo ""
echo "=== Test 5: Process Limits ==="
create_test_files 200 "task"

# Monitor process count during execution
echo -n "Checking process spawning... "
"$SCRIPT_DIR/status.sh" &
status_pid=$!

# Wait a moment for processes to spawn
sleep 1

# Count child processes
child_count=$(pgrep -P "$status_pid" 2>/dev/null | wc -l | tr -d ' \n' || echo "0")

# Wait for completion
wait "$status_pid"

if [ "$child_count" -lt 20 ]; then
    echo -e "${GREEN}PASSED${NC} (spawned $child_count child processes)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAILED${NC} (spawned $child_count child processes, limit is 20)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Resource cleanup
echo ""
echo "=== Test 6: Resource Cleanup ==="

# Get initial FD count
initial_fd=$(lsof -p $$ 2>/dev/null | wc -l)

# Run multiple scripts
for i in {1..5}; do
    "$SCRIPT_DIR/status.sh" >/dev/null 2>&1
    "$SCRIPT_DIR/standup.sh" >/dev/null 2>&1
done

# Check FD count after
final_fd=$(lsof -p $$ 2>/dev/null | wc -l)
leaked=$((final_fd - initial_fd))

if [ "$leaked" -le 5 ]; then
    echo -e "File descriptor check: ${GREEN}PASSED${NC} ($leaked FDs leaked)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "File descriptor check: ${RED}FAILED${NC} ($leaked FDs leaked)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
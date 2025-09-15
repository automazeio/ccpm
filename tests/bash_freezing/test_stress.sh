#!/bin/bash

# Stress tests for bash freezing fixes
# Tests scripts with extreme conditions and large file counts

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/ccpm-stress-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../.claude/scripts/pm" && pwd)"
DEBUG_WRAPPER="$(cd "$(dirname "$0")/../../.claude/scripts" && pwd)/debug-wrapper.sh"
PROFILE_SCRIPT="$(cd "$(dirname "$0")/../../.claude/scripts" && pwd)/profile.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup
cleanup() {
    echo "Cleaning up stress test environment..."
    rm -rf "$TEST_DIR"
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

# Setup environment
setup_stress_env() {
    echo "Setting up stress test environment in $TEST_DIR..."
    mkdir -p "$TEST_DIR/.claude/prds"
    mkdir -p "$TEST_DIR/.claude/epics"
    cd "$TEST_DIR"
}

# Create many files
create_many_files() {
    local count=$1
    echo "Creating $count test files..."

    # Create PRDs
    echo -n "  PRDs: "
    for i in $(seq 1 $((count/3))); do
        cat > ".claude/prds/stress-prd-$i.md" <<EOF
name: Stress Test PRD $i
status: $([ $((i % 3)) -eq 0 ] && echo "implemented" || echo "backlog")
description: This is a stress test PRD number $i with some content to make it realistic
created: $(date -Iseconds)
priority: $([ $((i % 2)) -eq 0 ] && echo "high" || echo "medium")
EOF
        [ $((i % 50)) -eq 0 ] && echo -n "."
    done
    echo " done"

    # Create Epics with tasks
    echo -n "  Epics: "
    for i in $(seq 1 $((count/5))); do
        local epic_dir=".claude/epics/stress-epic-$i"
        mkdir -p "$epic_dir"

        cat > "$epic_dir/epic.md" <<EOF
name: Stress Test Epic $i
status: open
description: Stress test epic with many tasks
created: $(date -Iseconds)
EOF

        # Create tasks for each epic
        for j in $(seq 1 10); do
            local task_id=$((i * 10 + j))
            cat > "$epic_dir/$task_id.md" <<EOF
name: Stress Task $task_id
status: $([ $((j % 3)) -eq 0 ] && echo "closed" || echo "open")
priority: high
depends_on: $([ $((j % 4)) -eq 0 ] && echo "[$((task_id - 1))]" || echo "[]")
description: Task $task_id in epic $i
assigned_to: stress-tester
created: $(date -Iseconds)
EOF
        done
        [ $((i % 20)) -eq 0 ] && echo -n "."
    done
    echo " done"
}

# Create very large files
create_large_files() {
    local size_mb=$1
    echo "Creating large files (${size_mb}MB each)..."

    # Create a large PRD
    {
        echo "name: Large PRD"
        echo "status: backlog"
        echo "content: |"
        # Generate large content
        for i in $(seq 1 $((size_mb * 1000))); do
            echo "  This is line $i of large content. It contains various keywords like open, closed, task, epic, and more text to fill space."
        done
    } > ".claude/prds/large-file.md"

    echo "  Created large-file.md"
}

# Create deep directory structure
create_deep_structure() {
    local depth=$1
    echo "Creating deep directory structure (depth: $depth)..."

    local path=".claude/epics"
    for i in $(seq 1 "$depth"); do
        path="$path/deep-level-$i"
        mkdir -p "$path"
        echo "name: Deep Epic $i" > "$path/epic.md"
    done
    echo "  Created $depth levels"
}

# Test function with timeout
run_stress_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout="${3:-30}"

    echo -n "Stress testing $test_name... "

    local start_time=$(date +%s)
    local output
    local exit_code=0

    # Run with debug wrapper for monitoring
    if TIMEOUT_SECONDS="$timeout" MAX_OUTPUT_LINES=100 \
       "$DEBUG_WRAPPER" $test_command >/tmp/stress-output-$$.log 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Check if it completed within timeout
    if [ "$exit_code" -eq 124 ]; then
        echo -e "${RED}TIMEOUT${NC} (>${timeout}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        tail -20 /tmp/stress-output-$$.log
        return 1
    elif [ "$exit_code" -eq 0 ] && [ "$duration" -lt "$timeout" ]; then
        echo -e "${GREEN}PASSED${NC} (${duration}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC} (exit: $exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        tail -20 /tmp/stress-output-$$.log
        return 1
    fi
}

# Performance benchmark
benchmark_script() {
    local script="$1"
    local description="$2"

    echo ""
    echo "Benchmarking $script - $description"

    # Run with profiler
    "$PROFILE_SCRIPT" "$SCRIPT_DIR/$script" 2>&1 | tail -30
}

# Main stress tests
echo -e "${BLUE}=== CCPM Bash Freezing Stress Tests ===${NC}"
echo "Test directory: $TEST_DIR"
echo ""

setup_stress_env

# Test 1: Many files (1000+)
echo -e "${YELLOW}=== Test 1: 1000+ Files ===${NC}"
create_many_files 1000
run_stress_test "status.sh (1000 files)" "$SCRIPT_DIR/status.sh" 30
run_stress_test "standup.sh (1000 files)" "$SCRIPT_DIR/standup.sh" 30
run_stress_test "search.sh (1000 files)" "$SCRIPT_DIR/search.sh test" 30

# Test 2: Very large files
echo ""
echo -e "${YELLOW}=== Test 2: Large Files ===${NC}"
create_large_files 5
run_stress_test "search.sh (large files)" "$SCRIPT_DIR/search.sh line" 30

# Test 3: Deep directory structure
echo ""
echo -e "${YELLOW}=== Test 3: Deep Directory Structure ===${NC}"
create_deep_structure 20
run_stress_test "epic-list.sh (deep dirs)" "$SCRIPT_DIR/epic-list.sh" 30

# Test 4: Concurrent execution
echo ""
echo -e "${YELLOW}=== Test 4: Concurrent Execution ===${NC}"
echo -n "Running 10 scripts concurrently... "

start_time=$(date +%s)
for i in {1..10}; do
    "$SCRIPT_DIR/status.sh" >/dev/null 2>&1 &
done

# Wait for all to complete
wait
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ "$duration" -lt 60 ]; then
    echo -e "${GREEN}PASSED${NC} (${duration}s)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAILED${NC} (took ${duration}s, limit 60s)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Rapid sequential execution
echo ""
echo -e "${YELLOW}=== Test 5: Rapid Sequential Execution ===${NC}"
echo -n "Running 50 sequential status checks... "

start_time=$(date +%s)
for i in {1..50}; do
    "$SCRIPT_DIR/status.sh" >/dev/null 2>&1
done
end_time=$(date +%s)
duration=$((end_time - start_time))

avg_time=$((duration * 1000 / 50))  # milliseconds per execution
if [ "$avg_time" -lt 1000 ]; then
    echo -e "${GREEN}PASSED${NC} (avg ${avg_time}ms per run)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}SLOW${NC} (avg ${avg_time}ms per run)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Test 6: Memory usage
echo ""
echo -e "${YELLOW}=== Test 6: Memory Usage ===${NC}"
echo -n "Checking memory usage... "

# Create even more files
create_many_files 2000

# Monitor memory during execution
"$SCRIPT_DIR/status.sh" &
pid=$!

sleep 1
if [[ "$OSTYPE" == "darwin"* ]]; then
    mem_usage=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print int($1/1024)}' || echo 0)
else
    mem_usage=$(awk '/VmRSS/ {print int($2/1024)}' "/proc/$pid/status" 2>/dev/null || echo 0)
fi

wait "$pid"

if [ "$mem_usage" -lt 100 ]; then
    echo -e "${GREEN}PASSED${NC} (${mem_usage}MB used)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}HIGH${NC} (${mem_usage}MB used)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Performance benchmarks
echo ""
echo -e "${YELLOW}=== Performance Benchmarks ===${NC}"
benchmark_script "status.sh" "2000 files"

# Summary
echo ""
echo -e "${BLUE}=== Stress Test Summary ===${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All stress tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some stress tests failed${NC}"
    exit 1
fi
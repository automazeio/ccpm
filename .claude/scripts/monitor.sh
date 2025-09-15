#!/bin/bash

# Process monitoring utility for CCPM scripts
# Tracks process count, memory usage, file handles, and detects hanging operations

set -euo pipefail

# Configuration
MONITOR_PID=${1:-$$}
INTERVAL=${2:-1}
DURATION=${3:-0}  # 0 = continuous monitoring
OUTPUT_FILE=${4:-".claude/.monitoring.log"}

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Initialize monitoring
echo "=== CCPM Process Monitor ===" | tee -a "$OUTPUT_FILE"
echo "Monitoring PID: $MONITOR_PID" | tee -a "$OUTPUT_FILE"
echo "Start time: $(date)" | tee -a "$OUTPUT_FILE"
echo "---" | tee -a "$OUTPUT_FILE"

# Function to get process tree
get_process_tree() {
    local pid=$1
    if command -v pstree >/dev/null 2>&1; then
        pstree -p "$pid" 2>/dev/null || echo "Process $pid not found"
    else
        # Fallback for systems without pstree
        ps -ef | grep -E "^[^ ]+ +$pid|PPid.*$pid" | grep -v grep
    fi
}

# Function to count child processes
count_children() {
    local pid=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ps -o pid,ppid -ax | awk -v ppid="$pid" '$2==ppid {count++} END {print count+0}'
    else
        # Linux
        ps --no-headers -o pid --ppid="$pid" 2>/dev/null | wc -l
    fi
}

# Function to get memory usage
get_memory_usage() {
    local pid=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - get RSS in KB
        ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1/1024 " MB"}' || echo "0 MB"
    else
        # Linux - get RSS from /proc
        if [[ -f "/proc/$pid/status" ]]; then
            awk '/VmRSS/ {print $2/1024 " MB"}' "/proc/$pid/status"
        else
            echo "0 MB"
        fi
    fi
}

# Function to count open file descriptors
count_file_descriptors() {
    local pid=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -p "$pid" 2>/dev/null | tail -n +2 | wc -l
    elif [[ -d "/proc/$pid/fd" ]]; then
        ls "/proc/$pid/fd" 2>/dev/null | wc -l
    else
        echo "N/A"
    fi
}

# Function to detect zombie processes
check_zombies() {
    local pid=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ps aux | grep -E "^[^ ]+ +[0-9]+ .*<defunct>" | grep -v grep | wc -l
    else
        # Linux
        ps aux | grep " Z " | grep -v grep | wc -l
    fi
}

# Function to check if process is hanging (not using CPU)
check_hanging() {
    local pid=$1
    local cpu_usage

    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu_usage=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
    else
        cpu_usage=$(ps -o pcpu= -p "$pid" 2>/dev/null | tr -d ' ')
    fi

    if [[ -z "$cpu_usage" ]]; then
        echo "Process not found"
    elif (( $(echo "$cpu_usage < 0.1" | bc -l 2>/dev/null || echo 1) )); then
        echo "HANGING (CPU: ${cpu_usage}%)"
    else
        echo "Active (CPU: ${cpu_usage}%)"
    fi
}

# Main monitoring loop
iteration=0
start_time=$(date +%s)

while true; do
    iteration=$((iteration + 1))
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    # Check if process still exists
    if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
        echo -e "${RED}Process $MONITOR_PID terminated${NC}" | tee -a "$OUTPUT_FILE"
        break
    fi

    # Collect metrics
    echo "=== Iteration $iteration (${elapsed}s) ===" | tee -a "$OUTPUT_FILE"

    # Process count
    child_count=$(count_children "$MONITOR_PID")
    echo "Child processes: $child_count" | tee -a "$OUTPUT_FILE"

    # Memory usage
    mem_usage=$(get_memory_usage "$MONITOR_PID")
    echo "Memory usage: $mem_usage" | tee -a "$OUTPUT_FILE"

    # File descriptors
    fd_count=$(count_file_descriptors "$MONITOR_PID")
    echo "Open file descriptors: $fd_count" | tee -a "$OUTPUT_FILE"

    # Zombie processes
    zombie_count=$(check_zombies "$MONITOR_PID")
    if [[ "$zombie_count" -gt 0 ]]; then
        echo -e "${YELLOW}Zombie processes detected: $zombie_count${NC}" | tee -a "$OUTPUT_FILE"
    fi

    # Hanging check
    status=$(check_hanging "$MONITOR_PID")
    if [[ "$status" == *"HANGING"* ]]; then
        echo -e "${YELLOW}Status: $status${NC}" | tee -a "$OUTPUT_FILE"
    else
        echo -e "${GREEN}Status: $status${NC}" | tee -a "$OUTPUT_FILE"
    fi

    # Alerts
    if [[ "$child_count" -gt 50 ]]; then
        echo -e "${RED}ALERT: High process count! ($child_count)${NC}" | tee -a "$OUTPUT_FILE"
    fi

    if [[ "$fd_count" != "N/A" ]] && [[ "$fd_count" -gt 100 ]]; then
        echo -e "${RED}ALERT: High file descriptor count! ($fd_count)${NC}" | tee -a "$OUTPUT_FILE"
    fi

    # Check duration limit
    if [[ "$DURATION" -gt 0 ]] && [[ "$elapsed" -ge "$DURATION" ]]; then
        echo "Monitoring duration reached ($DURATION seconds)" | tee -a "$OUTPUT_FILE"
        break
    fi

    echo "---" | tee -a "$OUTPUT_FILE"
    sleep "$INTERVAL"
done

# Final summary
echo "=== Monitoring Summary ===" | tee -a "$OUTPUT_FILE"
echo "Total duration: ${elapsed}s" | tee -a "$OUTPUT_FILE"
echo "Total iterations: $iteration" | tee -a "$OUTPUT_FILE"
echo "End time: $(date)" | tee -a "$OUTPUT_FILE"

# Check for leftover processes
leftover=$(pgrep -P "$MONITOR_PID" 2>/dev/null | wc -l)
if [[ "$leftover" -gt 0 ]]; then
    echo -e "${YELLOW}WARNING: $leftover child processes still running${NC}" | tee -a "$OUTPUT_FILE"
fi
#!/bin/bash

# Performance profiler for CCPM scripts
# Profiles script execution, measures timing, I/O operations, and identifies bottlenecks

set -euo pipefail

# Configuration
SCRIPT_TO_PROFILE="$1"
shift
SCRIPT_ARGS="$@"

# Profiling options
PROFILE_DIR=${PROFILE_DIR:-".claude/.profiles"}
PROFILE_NAME=${PROFILE_NAME:-"$(basename "$SCRIPT_TO_PROFILE" .sh)-$(date +%s)"}
PROFILE_LOG="$PROFILE_DIR/${PROFILE_NAME}.log"
TRACE_LOG="$PROFILE_DIR/${PROFILE_NAME}.trace"
SUMMARY_LOG="$PROFILE_DIR/${PROFILE_NAME}.summary"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure profile directory exists
mkdir -p "$PROFILE_DIR"

# Function to measure command execution time
measure_time() {
    local start=$(date +%s%N)
    "$@"
    local exit_code=$?
    local end=$(date +%s%N)
    local duration=$((($end - $start) / 1000000))  # Convert to milliseconds
    echo "$duration"
    return $exit_code
}

# Function to trace system calls (if available)
trace_syscalls() {
    local script="$1"
    shift
    local args="$@"

    if command -v strace >/dev/null 2>&1; then
        # Linux - use strace
        strace -c -o "$TRACE_LOG.strace" "$script" "$args" 2>&1
    elif command -v dtruss >/dev/null 2>&1; then
        # macOS - use dtruss (requires sudo)
        echo "Note: System call tracing on macOS requires sudo" | tee -a "$PROFILE_LOG"
        # Skip if not running as root
        if [[ $EUID -eq 0 ]]; then
            dtruss -c "$script" "$args" 2>&1 | tee "$TRACE_LOG.dtruss"
        fi
    else
        echo "System call tracing not available" | tee -a "$PROFILE_LOG"
    fi
}

# Function to monitor I/O operations
monitor_io() {
    local pid=$1
    local output_file="$2"

    echo "=== I/O Operations ===" >> "$output_file"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use lsof
        while kill -0 "$pid" 2>/dev/null; do
            lsof -p "$pid" 2>/dev/null | grep -E "REG|DIR|PIPE" | head -20 >> "$output_file"
            sleep 0.5
        done
    else
        # Linux - use /proc
        while kill -0 "$pid" 2>/dev/null; do
            if [[ -d "/proc/$pid" ]]; then
                echo "Open files:" >> "$output_file"
                ls -la "/proc/$pid/fd" 2>/dev/null | head -20 >> "$output_file"
                echo "I/O stats:" >> "$output_file"
                cat "/proc/$pid/io" 2>/dev/null >> "$output_file"
            fi
            sleep 0.5
        done
    fi
}

# Function to profile bash script line by line
profile_bash_script() {
    local script="$1"
    shift
    local args="$@"

    echo -e "${CYAN}=== Bash Script Line Profiling ===${NC}" | tee -a "$PROFILE_LOG"

    # Create instrumented version of script
    local instrumented_script="$PROFILE_DIR/${PROFILE_NAME}.instrumented.sh"

    # Add profiling hooks to each command
    awk '
    BEGIN { print "#!/bin/bash\n"; print "PS4=\"+ \\$(date +\"%s.%N\") \\${BASH_SOURCE}:\\${LINENO}: \""; print "set -x" }
    /^#!/ { next }
    { print }
    ' "$script" > "$instrumented_script"

    chmod +x "$instrumented_script"

    # Run instrumented script
    bash "$instrumented_script" "$args" 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ ^\+\ ([0-9]+\.[0-9]+)\ (.+):([0-9]+):\ (.+) ]]; then
            local timestamp="${BASH_REMATCH[1]}"
            local source="${BASH_REMATCH[2]}"
            local lineno="${BASH_REMATCH[3]}"
            local command="${BASH_REMATCH[4]}"
            echo "[$timestamp] Line $lineno: $command" | tee -a "$TRACE_LOG"
        else
            echo "$line"
        fi
    done
}

# Print header
echo -e "${BLUE}=== CCPM Performance Profiler ===${NC}" | tee "$PROFILE_LOG"
echo "Script: $SCRIPT_TO_PROFILE" | tee -a "$PROFILE_LOG"
echo "Arguments: $SCRIPT_ARGS" | tee -a "$PROFILE_LOG"
echo "Profile name: $PROFILE_NAME" | tee -a "$PROFILE_LOG"
echo "Start time: $(date)" | tee -a "$PROFILE_LOG"
echo "---" | tee -a "$PROFILE_LOG"

# Check script exists
if [[ ! -f "$SCRIPT_TO_PROFILE" ]]; then
    echo -e "${RED}ERROR: Script not found: $SCRIPT_TO_PROFILE${NC}"
    exit 1
fi

# Baseline measurements
echo -e "${CYAN}=== Baseline Measurements ===${NC}" | tee -a "$PROFILE_LOG"

# Measure script size
SCRIPT_SIZE=$(wc -l < "$SCRIPT_TO_PROFILE")
echo "Script lines: $SCRIPT_SIZE" | tee -a "$PROFILE_LOG"

# Count different command types
echo "Command analysis:" | tee -a "$PROFILE_LOG"
echo "  find commands: $(grep -c "find " "$SCRIPT_TO_PROFILE" || echo 0)" | tee -a "$PROFILE_LOG"
echo "  grep commands: $(grep -c "grep " "$SCRIPT_TO_PROFILE" || echo 0)" | tee -a "$PROFILE_LOG"
echo "  loops: $(grep -cE "for |while |until " "$SCRIPT_TO_PROFILE" || echo 0)" | tee -a "$PROFILE_LOG"
echo "  pipes: $(grep -c "|" "$SCRIPT_TO_PROFILE" || echo 0)" | tee -a "$PROFILE_LOG"
echo "  subshells: $(grep -c "\$(" "$SCRIPT_TO_PROFILE" || echo 0)" | tee -a "$PROFILE_LOG"

# Profile execution
echo -e "${CYAN}=== Execution Profile ===${NC}" | tee -a "$PROFILE_LOG"

# Start monitoring I/O in background
IO_LOG="$PROFILE_DIR/${PROFILE_NAME}.io"
{
    # Run the script with time measurement
    TIMEFORMAT='real %R user %U sys %S'
    time {
        # If it's a bash script, profile line by line
        if head -1 "$SCRIPT_TO_PROFILE" | grep -q "#!/bin/bash"; then
            profile_bash_script "$SCRIPT_TO_PROFILE" "$SCRIPT_ARGS"
        else
            "$SCRIPT_TO_PROFILE" "$SCRIPT_ARGS"
        fi
    } 2>&1 | tee -a "$PROFILE_LOG"
} &

PROFILE_PID=$!

# Monitor I/O in background
monitor_io "$PROFILE_PID" "$IO_LOG" &
IO_MONITOR_PID=$!

# Wait for script to complete
wait "$PROFILE_PID"
SCRIPT_EXIT_CODE=$?

# Stop I/O monitoring
kill "$IO_MONITOR_PID" 2>/dev/null || true

echo "Exit code: $SCRIPT_EXIT_CODE" | tee -a "$PROFILE_LOG"

# Analyze results
echo -e "${CYAN}=== Performance Analysis ===${NC}" | tee "$SUMMARY_LOG"

# Analyze trace log for bottlenecks
if [[ -f "$TRACE_LOG" ]]; then
    echo -e "${YELLOW}Slowest operations:${NC}" | tee -a "$SUMMARY_LOG"

    # Extract timing from trace log and sort
    grep "^\[" "$TRACE_LOG" 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" =~ \[([0-9]+\.[0-9]+)\]\ Line\ ([0-9]+):\ (.+) ]]; then
            echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
        fi
    done | sort -rn | head -10 | while read -r timestamp lineno command; do
        echo "  Line $lineno (${timestamp}s): $command" | tee -a "$SUMMARY_LOG"
    done
fi

# Analyze I/O patterns
if [[ -f "$IO_LOG" ]]; then
    echo -e "${YELLOW}I/O Statistics:${NC}" | tee -a "$SUMMARY_LOG"
    echo "  Total file operations: $(grep -c "REG\|DIR" "$IO_LOG" 2>/dev/null || echo 0)" | tee -a "$SUMMARY_LOG"
    echo "  Pipe operations: $(grep -c "PIPE" "$IO_LOG" 2>/dev/null || echo 0)" | tee -a "$SUMMARY_LOG"
fi

# Identify patterns that could cause freezing
echo -e "${YELLOW}Potential Issues:${NC}" | tee -a "$SUMMARY_LOG"

# Check for find -exec patterns
if grep -q "find.*-exec.*grep" "$SCRIPT_TO_PROFILE"; then
    echo -e "  ${RED}WARNING: Found 'find -exec grep' pattern (causes process explosion)${NC}" | tee -a "$SUMMARY_LOG"
    grep -n "find.*-exec.*grep" "$SCRIPT_TO_PROFILE" | while IFS=: read -r lineno content; do
        echo "    Line $lineno: $content" | tee -a "$SUMMARY_LOG"
    done
fi

# Check for unbounded loops
if grep -qE "while true|until false" "$SCRIPT_TO_PROFILE"; then
    echo -e "  ${RED}WARNING: Found potentially infinite loop${NC}" | tee -a "$SUMMARY_LOG"
fi

# Check for missing output limits
if grep -q "find " "$SCRIPT_TO_PROFILE" && ! grep -q "head\|tail\|maxdepth" "$SCRIPT_TO_PROFILE"; then
    echo -e "  ${YELLOW}CAUTION: find commands without output limits${NC}" | tee -a "$SUMMARY_LOG"
fi

# Generate recommendations
echo -e "${GREEN}=== Recommendations ===${NC}" | tee -a "$SUMMARY_LOG"

if grep -q "find.*-exec.*grep" "$SCRIPT_TO_PROFILE"; then
    echo "1. Replace 'find -exec grep' with 'find | xargs grep'" | tee -a "$SUMMARY_LOG"
fi

if ! grep -q "set -euo pipefail" "$SCRIPT_TO_PROFILE"; then
    echo "2. Add 'set -euo pipefail' for better error handling" | tee -a "$SUMMARY_LOG"
fi

if grep -q "grep.*|.*head\|grep.*|.*tail" "$SCRIPT_TO_PROFILE"; then
    echo "3. Use grep's -m flag instead of piping to head" | tee -a "$SUMMARY_LOG"
fi

# Final summary
echo -e "${BLUE}=== Profile Complete ===${NC}" | tee -a "$SUMMARY_LOG"
echo "Profile saved to: $PROFILE_DIR/$PROFILE_NAME.*" | tee -a "$SUMMARY_LOG"
echo "View summary: cat $SUMMARY_LOG" | tee -a "$SUMMARY_LOG"

exit "$SCRIPT_EXIT_CODE"
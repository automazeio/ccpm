#!/bin/bash

# Debug wrapper for CCPM scripts
# Wraps any script execution with comprehensive debugging, timeouts, and cleanup

set -euo pipefail

# Configuration
SCRIPT_TO_RUN="$1"
shift
SCRIPT_ARGS="$@"

# Defaults
MAX_OUTPUT_LINES=${MAX_OUTPUT_LINES:-10000}
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
DEBUG_LOG=${DEBUG_LOG:-".claude/.debug-$(basename "$SCRIPT_TO_RUN" .sh)-$(date +%s).log"}
MONITOR_LOG=${MONITOR_LOG:-".claude/.monitor-$(basename "$SCRIPT_TO_RUN" .sh)-$(date +%s).log"}

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure log directory exists
mkdir -p "$(dirname "$DEBUG_LOG")"

# Function to clean up on exit
cleanup() {
    local exit_code=$?
    echo -e "${BLUE}=== Cleanup Started ===${NC}" | tee -a "$DEBUG_LOG"

    # Kill monitoring process if it exists
    if [[ -n "${MONITOR_PID:-}" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null || true
        echo "Stopped monitoring process" | tee -a "$DEBUG_LOG"
    fi

    # Kill script process if it's still running
    if [[ -n "${SCRIPT_PID:-}" ]] && kill -0 "$SCRIPT_PID" 2>/dev/null; then
        echo -e "${YELLOW}Script still running, terminating...${NC}" | tee -a "$DEBUG_LOG"
        kill -TERM "$SCRIPT_PID" 2>/dev/null || true
        sleep 2
        if kill -0 "$SCRIPT_PID" 2>/dev/null; then
            kill -KILL "$SCRIPT_PID" 2>/dev/null || true
        fi
    fi

    # Kill any child processes
    if [[ -n "${SCRIPT_PID:-}" ]]; then
        local children=$(pgrep -P "$SCRIPT_PID" 2>/dev/null || true)
        if [[ -n "$children" ]]; then
            echo "Cleaning up child processes: $children" | tee -a "$DEBUG_LOG"
            echo "$children" | xargs -r kill -TERM 2>/dev/null || true
            sleep 1
            echo "$children" | xargs -r kill -KILL 2>/dev/null || true
        fi
    fi

    # Check for zombie processes
    local zombies=$(ps aux | grep " Z " | grep -v grep | wc -l)
    if [[ "$zombies" -gt 0 ]]; then
        echo -e "${YELLOW}WARNING: $zombies zombie processes detected${NC}" | tee -a "$DEBUG_LOG"
    fi

    # Check for leaked file descriptors
    if [[ -n "${INITIAL_FD_COUNT:-}" ]]; then
        local final_fd_count=$(lsof -p $$ 2>/dev/null | tail -n +2 | wc -l)
        local leaked=$((final_fd_count - INITIAL_FD_COUNT))
        if [[ "$leaked" -gt 0 ]]; then
            echo -e "${YELLOW}WARNING: $leaked file descriptors may have leaked${NC}" | tee -a "$DEBUG_LOG"
        fi
    fi

    echo -e "${BLUE}=== Cleanup Completed (exit code: $exit_code) ===${NC}" | tee -a "$DEBUG_LOG"
    exit "$exit_code"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Function to monitor output size
monitor_output() {
    local output_file="$1"
    local max_lines="$2"
    local line_count=0

    while IFS= read -r line; do
        echo "$line"
        echo "$line" >> "$output_file"
        line_count=$((line_count + 1))

        if [[ "$line_count" -ge "$max_lines" ]]; then
            echo -e "${RED}ERROR: Output exceeded $max_lines lines, truncating...${NC}" | tee -a "$DEBUG_LOG"
            echo "--- OUTPUT TRUNCATED ---" | tee -a "$output_file"
            # Don't exit, just stop reading more
            cat > /dev/null  # Consume remaining output to prevent pipe issues
            break
        fi
    done
}

# Print header
echo -e "${BLUE}=== CCPM Debug Wrapper ===${NC}" | tee "$DEBUG_LOG"
echo "Script: $SCRIPT_TO_RUN" | tee -a "$DEBUG_LOG"
echo "Arguments: $SCRIPT_ARGS" | tee -a "$DEBUG_LOG"
echo "Timeout: ${TIMEOUT_SECONDS}s" | tee -a "$DEBUG_LOG"
echo "Max output: $MAX_OUTPUT_LINES lines" | tee -a "$DEBUG_LOG"
echo "Debug log: $DEBUG_LOG" | tee -a "$DEBUG_LOG"
echo "Start time: $(date)" | tee -a "$DEBUG_LOG"
echo "---" | tee -a "$DEBUG_LOG"

# Check script exists and is executable
if [[ ! -f "$SCRIPT_TO_RUN" ]]; then
    echo -e "${RED}ERROR: Script not found: $SCRIPT_TO_RUN${NC}" | tee -a "$DEBUG_LOG"
    exit 1
fi

if [[ ! -x "$SCRIPT_TO_RUN" ]]; then
    echo -e "${YELLOW}WARNING: Script not executable, attempting to run with bash${NC}" | tee -a "$DEBUG_LOG"
    SCRIPT_TO_RUN="bash $SCRIPT_TO_RUN"
fi

# Record initial state
INITIAL_FD_COUNT=$(lsof -p $$ 2>/dev/null | tail -n +2 | wc -l)
echo "Initial FD count: $INITIAL_FD_COUNT" | tee -a "$DEBUG_LOG"

# Start monitoring in background
echo "Starting process monitor..." | tee -a "$DEBUG_LOG"
bash "$(dirname "$0")/monitor.sh" $$ 2 "$TIMEOUT_SECONDS" "$MONITOR_LOG" &
MONITOR_PID=$!
echo "Monitor PID: $MONITOR_PID" | tee -a "$DEBUG_LOG"

# Create temp file for capturing output
TEMP_OUTPUT=$(mktemp)
trap "rm -f $TEMP_OUTPUT" EXIT

# Run the script with timeout and output monitoring
echo -e "${GREEN}=== Starting Script Execution ===${NC}" | tee -a "$DEBUG_LOG"

# Execute with timeout, capturing both stdout and stderr
# Check if timeout command exists
# Check for line buffering support
if command -v stdbuf >/dev/null 2>&1; then
    BUFFER_CMD="stdbuf -oL -eL"
elif command -v gstdbuf >/dev/null 2>&1; then
    BUFFER_CMD="gstdbuf -oL -eL"
else
    BUFFER_CMD=""  # No buffering control available
fi

if command -v timeout >/dev/null 2>&1; then
    # Use GNU timeout if available
    {
        timeout --preserve-status "$TIMEOUT_SECONDS" \
            $BUFFER_CMD \
            $SCRIPT_TO_RUN $SCRIPT_ARGS 2>&1 | \
            monitor_output "$TEMP_OUTPUT" "$MAX_OUTPUT_LINES"
    } &
elif command -v gtimeout >/dev/null 2>&1; then
    # Use gtimeout on macOS (from coreutils)
    {
        gtimeout --preserve-status "$TIMEOUT_SECONDS" \
            $BUFFER_CMD \
            $SCRIPT_TO_RUN $SCRIPT_ARGS 2>&1 | \
            monitor_output "$TEMP_OUTPUT" "$MAX_OUTPUT_LINES"
    } &
else
    # Fallback: Run without timeout but with background monitoring
    echo -e "${YELLOW}WARNING: timeout command not found, using fallback${NC}" | tee -a "$DEBUG_LOG"
    {
        $BUFFER_CMD $SCRIPT_TO_RUN $SCRIPT_ARGS 2>&1 | \
            monitor_output "$TEMP_OUTPUT" "$MAX_OUTPUT_LINES"
    } &
fi

SCRIPT_PID=$!
echo "Script PID: $SCRIPT_PID" | tee -a "$DEBUG_LOG"

# Wait for script to complete
wait "$SCRIPT_PID"
SCRIPT_EXIT_CODE=$?

# Stop monitoring
if kill -0 "$MONITOR_PID" 2>/dev/null; then
    kill "$MONITOR_PID" 2>/dev/null || true
fi

# Report results
echo -e "${GREEN}=== Execution Completed ===${NC}" | tee -a "$DEBUG_LOG"
echo "Exit code: $SCRIPT_EXIT_CODE" | tee -a "$DEBUG_LOG"
echo "End time: $(date)" | tee -a "$DEBUG_LOG"

# Check for timeout
if [[ "$SCRIPT_EXIT_CODE" -eq 124 ]]; then
    echo -e "${RED}ERROR: Script timed out after ${TIMEOUT_SECONDS}s${NC}" | tee -a "$DEBUG_LOG"
elif [[ "$SCRIPT_EXIT_CODE" -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS: Script completed successfully${NC}" | tee -a "$DEBUG_LOG"
else
    echo -e "${YELLOW}WARNING: Script exited with code $SCRIPT_EXIT_CODE${NC}" | tee -a "$DEBUG_LOG"
fi

# Display monitoring summary
if [[ -f "$MONITOR_LOG" ]]; then
    echo -e "${BLUE}=== Monitoring Summary ===${NC}" | tee -a "$DEBUG_LOG"
    tail -20 "$MONITOR_LOG" | tee -a "$DEBUG_LOG"
fi

# Output line count
OUTPUT_LINES=$(wc -l < "$TEMP_OUTPUT")
echo "Total output lines: $OUTPUT_LINES" | tee -a "$DEBUG_LOG"

# Clean up temp file
rm -f "$TEMP_OUTPUT"

exit "$SCRIPT_EXIT_CODE"
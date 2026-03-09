#!/bin/bash
# report.sh - Test report generation for E2E testing
#
# Generates test reports in multiple formats:
# - Console output (human readable)
# - JSON (machine readable)
# - Markdown (for GitHub/docs)

set -eo pipefail
# Note: Not using -u because empty arrays cause "unbound variable" errors
# in subshell expansions within heredocs

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Report data
REPORT_SCENARIO_NAME=""
REPORT_SCENARIO_FILE=""
REPORT_START_TIME=""
REPORT_END_TIME=""
REPORT_DURATION=""
REPORT_STATUS="pending"
REPORT_TEST_DIR=""
declare -a REPORT_STAGES
declare -a REPORT_STAGE_STATUSES
declare -a REPORT_STAGE_DURATIONS
declare -a REPORT_ERRORS
declare -A REPORT_METRICS

# Initialize report
# Usage: report_init <scenario_name> <scenario_file> <test_dir>
report_init() {
    REPORT_SCENARIO_NAME="$1"
    REPORT_SCENARIO_FILE="$2"
    REPORT_TEST_DIR="${3:-}"
    REPORT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Reinitialize arrays to ensure clean state
    REPORT_METRICS=()  # Clear associative array
    REPORT_STATUS="running"
    REPORT_STAGES=()
    REPORT_STAGE_STATUSES=()
    REPORT_STAGE_DURATIONS=()
    REPORT_ERRORS=()
}

# Start a test stage
# Usage: report_stage_start <stage_name>
report_stage_start() {
    local stage="$1"
    REPORT_STAGES+=("$stage")
    REPORT_STAGE_STATUSES+=("running")
    REPORT_STAGE_DURATIONS+=("$(date +%s)")

    echo -e "\n${BLUE}[$((${#REPORT_STAGES[@]}))/5]${NC} ${BOLD}$stage${NC}..."
}

# End a test stage
# Usage: report_stage_end <status> [message]
report_stage_end() {
    local status="$1"
    local message="${2:-}"
    local idx=$((${#REPORT_STAGES[@]} - 1))

    local start_time=${REPORT_STAGE_DURATIONS[$idx]}
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    REPORT_STAGE_STATUSES[$idx]="$status"
    REPORT_STAGE_DURATIONS[$idx]="$duration"

    if [[ "$status" == "pass" ]]; then
        echo -e "  ${GREEN}✓${NC} ${message:-Done} (${duration}s)"
    elif [[ "$status" == "fail" ]]; then
        echo -e "  ${RED}✗${NC} ${message:-Failed} (${duration}s)"
        if [[ -n "$message" ]]; then
            REPORT_ERRORS+=("${REPORT_STAGES[$idx]}: $message")
        fi
    elif [[ "$status" == "skip" ]]; then
        echo -e "  ${YELLOW}⊘${NC} ${message:-Skipped}"
    fi
}

# Record an error
# Usage: report_error <message>
report_error() {
    local message="$1"
    REPORT_ERRORS+=("$message")
    echo -e "  ${RED}Error:${NC} $message"
}

# Set a metric
# Usage: report_metric <key> <value>
report_metric() {
    local key="$1"
    local value="$2"
    REPORT_METRICS["$key"]="$value"
}

# Finalize report
# Usage: report_finalize <status>
report_finalize() {
    local status="$1"
    REPORT_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    REPORT_STATUS="$status"

    # Calculate total duration
    local start_epoch end_epoch
    start_epoch=$(date -d "$REPORT_START_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$REPORT_START_TIME" +%s 2>/dev/null || echo "0")
    end_epoch=$(date -d "$REPORT_END_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$REPORT_END_TIME" +%s 2>/dev/null || echo "0")

    if [[ $start_epoch -gt 0 && $end_epoch -gt 0 ]]; then
        REPORT_DURATION=$((end_epoch - start_epoch))
    else
        REPORT_DURATION=0
    fi
}

# Format duration in human readable format
format_duration() {
    local seconds="$1"
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Print console report
report_console() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    if [[ "$REPORT_STATUS" == "pass" ]]; then
        echo -e "${GREEN}${BOLD}=== PASSED ===${NC} ${REPORT_SCENARIO_NAME}"
    elif [[ "$REPORT_STATUS" == "fail" ]]; then
        echo -e "${RED}${BOLD}=== FAILED ===${NC} ${REPORT_SCENARIO_NAME}"
    else
        echo -e "${YELLOW}${BOLD}=== $REPORT_STATUS ===${NC} ${REPORT_SCENARIO_NAME}"
    fi

    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Summary
    echo -e "${BOLD}Summary:${NC}"
    echo "  Scenario: $REPORT_SCENARIO_NAME"
    echo "  Duration: $(format_duration $REPORT_DURATION)"
    echo "  Started:  $REPORT_START_TIME"
    echo "  Ended:    $REPORT_END_TIME"

    if [[ -n "$REPORT_TEST_DIR" ]]; then
        echo "  Test Dir: $REPORT_TEST_DIR"
    fi

    echo ""

    # Stage results
    echo -e "${BOLD}Stages:${NC}"
    for i in "${!REPORT_STAGES[@]}"; do
        local stage="${REPORT_STAGES[$i]}"
        local status="${REPORT_STAGE_STATUSES[$i]}"
        local duration="${REPORT_STAGE_DURATIONS[$i]}"

        local status_icon
        case "$status" in
            pass) status_icon="${GREEN}✓${NC}" ;;
            fail) status_icon="${RED}✗${NC}" ;;
            skip) status_icon="${YELLOW}⊘${NC}" ;;
            *) status_icon="${CYAN}?${NC}" ;;
        esac

        printf "  %b %-35s %s\n" "$status_icon" "$stage" "(${duration}s)"
    done

    echo ""

    # Metrics
    if [[ ${#REPORT_METRICS[@]} -gt 0 ]]; then
        echo -e "${BOLD}Metrics:${NC}"
        for key in "${!REPORT_METRICS[@]}"; do
            printf "  %-25s %s\n" "$key:" "${REPORT_METRICS[$key]}"
        done
        echo ""
    fi

    # Errors
    if [[ ${#REPORT_ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}Errors:${NC}"
        for error in "${REPORT_ERRORS[@]}"; do
            echo "  - $error"
        done
        echo ""
    fi

    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# Generate JSON report
# Usage: report_json <output_file>
report_json() {
    local output_file="${1:-/dev/stdout}"

    cat > "$output_file" << JSON_EOF
{
  "scenario": {
    "name": "$REPORT_SCENARIO_NAME",
    "file": "$REPORT_SCENARIO_FILE"
  },
  "execution": {
    "status": "$REPORT_STATUS",
    "start_time": "$REPORT_START_TIME",
    "end_time": "$REPORT_END_TIME",
    "duration_seconds": $REPORT_DURATION,
    "test_dir": "$REPORT_TEST_DIR"
  },
  "stages": [
$(for i in "${!REPORT_STAGES[@]}"; do
    local comma=""
    [[ $i -lt $((${#REPORT_STAGES[@]} - 1)) ]] && comma=","
    echo "    {\"name\": \"${REPORT_STAGES[$i]}\", \"status\": \"${REPORT_STAGE_STATUSES[$i]}\", \"duration_seconds\": ${REPORT_STAGE_DURATIONS[$i]}}$comma"
done)
  ],
  "metrics": {$(
    if [[ ${#REPORT_METRICS[@]} -gt 0 ]]; then
        local first=true
        for key in "${!REPORT_METRICS[@]}"; do
            [[ "$first" != "true" ]] && echo -n ","
            first=false
            echo ""
            echo -n "    \"$key\": \"${REPORT_METRICS[$key]}\""
        done
        echo ""
    fi
)  },
  "errors": [$(
    if [[ ${#REPORT_ERRORS[@]} -gt 0 ]]; then
        for i in "${!REPORT_ERRORS[@]}"; do
            local comma=""
            [[ $i -lt $((${#REPORT_ERRORS[@]} - 1)) ]] && comma=","
            local escaped_error="${REPORT_ERRORS[$i]//\"/\\\"}"
            echo ""
            echo -n "    \"$escaped_error\"$comma"
        done
        echo ""
    fi
)  ]
}
JSON_EOF
}

# Generate Markdown report
# Usage: report_markdown <output_file>
report_markdown() {
    local output_file="${1:-/dev/stdout}"

    local status_badge
    case "$REPORT_STATUS" in
        pass) status_badge="![Pass](https://img.shields.io/badge/status-passed-brightgreen)" ;;
        fail) status_badge="![Fail](https://img.shields.io/badge/status-failed-red)" ;;
        *) status_badge="![Status](https://img.shields.io/badge/status-$REPORT_STATUS-yellow)" ;;
    esac

    cat > "$output_file" << MARKDOWN_EOF
# E2E Test Report: $REPORT_SCENARIO_NAME

$status_badge

## Summary

| Metric | Value |
|--------|-------|
| Scenario | $REPORT_SCENARIO_NAME |
| Status | **$REPORT_STATUS** |
| Duration | $(format_duration $REPORT_DURATION) |
| Started | $REPORT_START_TIME |
| Ended | $REPORT_END_TIME |
| Test Directory | \`$REPORT_TEST_DIR\` |

## Stages

| Stage | Status | Duration |
|-------|--------|----------|
$(for i in "${!REPORT_STAGES[@]}"; do
    local stage="${REPORT_STAGES[$i]}"
    local status="${REPORT_STAGE_STATUSES[$i]}"
    local duration="${REPORT_STAGE_DURATIONS[$i]}"
    local status_emoji
    case "$status" in
        pass) status_emoji="✅" ;;
        fail) status_emoji="❌" ;;
        skip) status_emoji="⏭️" ;;
        *) status_emoji="❓" ;;
    esac
    echo "| $stage | $status_emoji $status | ${duration}s |"
done)

## Metrics

$(if [[ ${#REPORT_METRICS[@]} -gt 0 ]]; then
    echo "| Metric | Value |"
    echo "|--------|-------|"
    for key in "${!REPORT_METRICS[@]}"; do
        echo "| $key | ${REPORT_METRICS[$key]} |"
    done
else
    echo "_No metrics recorded_"
fi)

## Errors

$(if [[ ${#REPORT_ERRORS[@]} -gt 0 ]]; then
    for error in "${REPORT_ERRORS[@]}"; do
        echo "- $error"
    done
else
    echo "_No errors_"
fi)

---
_Generated by Robert PM E2E Test Harness_
MARKDOWN_EOF
}

# Print test progress bar
# Usage: report_progress <current> <total> <message>
report_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-}"

    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf "\r  ${CYAN}[%s]${NC} %3d%% %s" "$bar" "$percent" "$message"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Log a message to both console and log file
# Usage: report_log <level> <message> [log_file]
report_log() {
    local level="$1"
    local message="$2"
    local log_file="${3:-}"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local level_color
    case "$level" in
        INFO) level_color="$BLUE" ;;
        WARN) level_color="$YELLOW" ;;
        ERROR) level_color="$RED" ;;
        DEBUG) level_color="$CYAN" ;;
        *) level_color="$NC" ;;
    esac

    # Console output
    echo -e "${level_color}[$level]${NC} $message"

    # Log file output (if provided)
    if [[ -n "$log_file" ]]; then
        echo "[$timestamp] [$level] $message" >> "$log_file"
    fi
}

# Export functions
export -f report_init
export -f report_stage_start
export -f report_stage_end
export -f report_error
export -f report_metric
export -f report_finalize
export -f format_duration
export -f report_console
export -f report_json
export -f report_markdown
export -f report_progress
export -f report_log

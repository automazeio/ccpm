#!/bin/bash

# Health check script for CCPM
# Performs periodic checks for orphaned processes, resource usage, and performance

set -euo pipefail

# Configuration
CHECK_INTERVAL=${1:-300}  # Default: 5 minutes
LOG_DIR=${LOG_DIR:-".claude/.health"}
ALERT_FILE="$LOG_DIR/alerts.log"
METRICS_FILE="$LOG_DIR/metrics.csv"

# Thresholds
MAX_ORPHANED_PROCESSES=5
MAX_EXECUTION_TIME=10  # seconds
MAX_MEMORY_MB=100
MAX_FD_COUNT=50

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Initialize metrics file with headers if not exists
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,check_type,metric,value,status" > "$METRICS_FILE"
fi

# Function to log metrics
log_metric() {
    local check_type="$1"
    local metric="$2"
    local value="$3"
    local status="$4"

    echo "$(date +%s),$check_type,$metric,$value,$status" >> "$METRICS_FILE"

    if [ "$status" = "ALERT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$status] $check_type: $metric = $value" >> "$ALERT_FILE"
    fi
}

# Check for orphaned processes
check_orphaned_processes() {
    echo -n "Checking for orphaned processes... "

    # Look for ccpm-related processes without parent
    local orphaned=0

    # Check for zombie processes
    if [[ "$OSTYPE" == "darwin"* ]]; then
        orphaned=$(ps aux | grep -E "claude|ccpm" | grep " Z " | grep -v grep | wc -l)
    else
        orphaned=$(ps aux | grep -E "claude|ccpm" | grep "<defunct>" | grep -v grep | wc -l)
    fi

    # Check for long-running scripts
    local long_running=$(ps aux | grep -E "\.claude/scripts/.*\.sh" | grep -v grep | grep -v health-check | wc -l)

    local total=$((orphaned + long_running))

    if [ "$total" -gt "$MAX_ORPHANED_PROCESSES" ]; then
        echo -e "${RED}ALERT${NC} ($total processes)"
        log_metric "processes" "orphaned" "$total" "ALERT"

        # Try to clean up
        echo "  Attempting cleanup..."
        ps aux | grep -E "\.claude/scripts/.*\.sh" | grep -v grep | grep -v health-check | awk '{print $2}' | xargs -r kill -TERM 2>/dev/null || true
    else
        echo -e "${GREEN}OK${NC} ($total processes)"
        log_metric "processes" "orphaned" "$total" "OK"
    fi
}

# Check script execution times
check_execution_times() {
    echo -n "Checking script execution times... "

    local script_dir=".claude/scripts/pm"
    if [ ! -d "$script_dir" ]; then
        echo -e "${YELLOW}SKIP${NC} (no scripts directory)"
        return
    fi

    # Test status.sh execution time
    local start=$(date +%s)
    timeout 30 "$script_dir/status.sh" >/dev/null 2>&1 || true
    local end=$(date +%s)
    local duration=$((end - start))

    if [ "$duration" -gt "$MAX_EXECUTION_TIME" ]; then
        echo -e "${YELLOW}SLOW${NC} (${duration}s)"
        log_metric "performance" "status_execution_time" "$duration" "SLOW"
    else
        echo -e "${GREEN}OK${NC} (${duration}s)"
        log_metric "performance" "status_execution_time" "$duration" "OK"
    fi
}

# Check resource usage
check_resource_usage() {
    echo -n "Checking resource usage... "

    # Check memory usage of shell processes
    local total_mem=0
    local high_mem_procs=0

    if [[ "$OSTYPE" == "darwin"* ]]; then
        while IFS= read -r line; do
            mem=$(echo "$line" | awk '{print int($6/1024)}')  # RSS in MB
            if [ "$mem" -gt "$MAX_MEMORY_MB" ]; then
                high_mem_procs=$((high_mem_procs + 1))
            fi
            total_mem=$((total_mem + mem))
        done < <(ps aux | grep -E "bash.*claude" | grep -v grep)
    else
        while IFS= read -r pid; do
            if [ -f "/proc/$pid/status" ]; then
                mem=$(awk '/VmRSS/ {print int($2/1024)}' "/proc/$pid/status")
                if [ "$mem" -gt "$MAX_MEMORY_MB" ]; then
                    high_mem_procs=$((high_mem_procs + 1))
                fi
                total_mem=$((total_mem + mem))
            fi
        done < <(pgrep -f "bash.*claude")
    fi

    if [ "$high_mem_procs" -gt 0 ]; then
        echo -e "${YELLOW}HIGH${NC} ($high_mem_procs processes > ${MAX_MEMORY_MB}MB)"
        log_metric "resources" "high_memory_processes" "$high_mem_procs" "HIGH"
    else
        echo -e "${GREEN}OK${NC} (total: ${total_mem}MB)"
        log_metric "resources" "total_memory_mb" "$total_mem" "OK"
    fi
}

# Check file descriptors
check_file_descriptors() {
    echo -n "Checking file descriptors... "

    local max_fd=0
    local problem_pids=""

    if command -v lsof >/dev/null 2>&1; then
        while IFS= read -r pid; do
            [ -z "$pid" ] && continue
            fd_count=$(lsof -p "$pid" 2>/dev/null | tail -n +2 | wc -l)
            if [ "$fd_count" -gt "$MAX_FD_COUNT" ]; then
                problem_pids="$problem_pids $pid($fd_count)"
            fi
            [ "$fd_count" -gt "$max_fd" ] && max_fd=$fd_count
        done < <(pgrep -f "bash.*claude" 2>/dev/null)
    fi

    if [ -n "$problem_pids" ]; then
        echo -e "${YELLOW}HIGH${NC} (PIDs with >$MAX_FD_COUNT FDs:$problem_pids)"
        log_metric "resources" "max_file_descriptors" "$max_fd" "HIGH"
    else
        echo -e "${GREEN}OK${NC} (max: $max_fd)"
        log_metric "resources" "max_file_descriptors" "$max_fd" "OK"
    fi
}

# Check for common issues
check_common_issues() {
    echo -n "Checking for common issues... "

    local issues=0
    local issue_list=""

    # Check for find -exec grep patterns (old problematic pattern)
    if grep -r "find.*-exec.*grep" .claude/scripts/pm/*.sh 2>/dev/null | grep -v "^#"; then
        issues=$((issues + 1))
        issue_list="$issue_list find-exec-grep"
    fi

    # Check for missing set -euo pipefail
    for script in .claude/scripts/pm/*.sh; do
        [ -f "$script" ] || continue
        if ! grep -q "set -euo pipefail" "$script"; then
            issues=$((issues + 1))
            issue_list="$issue_list missing-pipefail"
            break
        fi
    done

    # Check for infinite loops
    if grep -r "while true\|until false" .claude/scripts/pm/*.sh 2>/dev/null | grep -v "^#"; then
        issues=$((issues + 1))
        issue_list="$issue_list infinite-loops"
    fi

    if [ "$issues" -gt 0 ]; then
        echo -e "${YELLOW}ISSUES FOUND${NC} ($issue_list)"
        log_metric "quality" "code_issues" "$issues" "ISSUES"
    else
        echo -e "${GREEN}OK${NC}"
        log_metric "quality" "code_issues" "0" "OK"
    fi
}

# Generate daily report
generate_report() {
    local report_file="$LOG_DIR/daily-report-$(date +%Y%m%d).txt"

    {
        echo "=== CCPM Health Report ==="
        echo "Date: $(date)"
        echo ""

        echo "Recent Alerts:"
        tail -10 "$ALERT_FILE" 2>/dev/null || echo "  No recent alerts"
        echo ""

        echo "Performance Summary (last 24h):"
        if [ -f "$METRICS_FILE" ]; then
            local day_ago=$(($(date +%s) - 86400))
            awk -F, -v cutoff="$day_ago" '
                $1 > cutoff && $2 == "performance" {
                    sum[$3] += $4; count[$3]++
                }
                END {
                    for (metric in sum) {
                        printf "  %s: avg %.2fs\n", metric, sum[metric]/count[metric]
                    }
                }
            ' "$METRICS_FILE"
        fi
        echo ""

        echo "Resource Usage (current):"
        echo "  Processes: $(pgrep -f "claude" | wc -l)"
        echo "  Scripts running: $(ps aux | grep -c "\.sh" | grep -v grep || echo 0)"
        echo ""

    } > "$report_file"

    echo "Report saved to: $report_file"
}

# Main health check loop
main() {
    echo -e "${BLUE}=== CCPM Health Check Service ===${NC}"
    echo "Check interval: ${CHECK_INTERVAL}s"
    echo "Log directory: $LOG_DIR"
    echo "Press Ctrl+C to stop"
    echo ""

    while true; do
        echo "=== Health Check $(date '+%H:%M:%S') ==="

        check_orphaned_processes
        check_execution_times
        check_resource_usage
        check_file_descriptors
        check_common_issues

        # Generate daily report at midnight
        if [ "$(date +%H%M)" = "0000" ]; then
            generate_report
        fi

        echo ""

        # Check if we should continue
        if [ "${RUN_ONCE:-}" = "true" ]; then
            break
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# Handle single run mode
if [ "${1:-}" = "--once" ]; then
    RUN_ONCE=true
    main

    # Exit with error if any alerts
    if [ -f "$ALERT_FILE" ] && [ -s "$ALERT_FILE" ]; then
        tail -1 "$ALERT_FILE" | grep -q "$(date +%Y-%m-%d)" && exit 1
    fi
    exit 0
else
    main
fi
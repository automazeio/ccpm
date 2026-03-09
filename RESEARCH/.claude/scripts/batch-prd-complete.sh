#!/bin/bash
# batch-prd-complete.sh - Process multiple PRDs with clean Claude agents
#
# Usage:
#   ./batch-prd-complete.sh 61 77 62                 # Just numbers (auto-resolved)
#   ./batch-prd-complete.sh prd1 prd2 prd3           # Full names
#   ./batch-prd-complete.sh -j 3 prd1 prd2 prd3     # 3 parallel
#   ./batch-prd-complete.sh --dry-run prd1 prd2    # Preview only
#
# Each PRD gets a fresh Claude Code session, avoiding context pollution.
# PRD numbers are auto-resolved to full names (61 -> 61-journey-capture-phase)

set -uo pipefail

PARALLEL=1
DRY_RUN=false
RAW_PRDS=()

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -j|--jobs)
      PARALLEL="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-j N] [--dry-run] <prd1> [prd2] ..."
      echo ""
      echo "Options:"
      echo "  -j, --jobs N    Run N PRDs in parallel (default: 1)"
      echo "  --dry-run       Show what would run without executing"
      echo "  -h, --help      Show this help message"
      echo ""
      echo "PRD names can be:"
      echo "  - Full name: 61-journey-capture-phase"
      echo "  - Just number: 61 (auto-resolved to full name)"
      echo ""
      echo "Each PRD gets a fresh Claude Code session to avoid context pollution."
      echo "Logs are saved to .claude/logs/batch-<timestamp>/"
      exit 0
      ;;
    *)
      RAW_PRDS+=("$1")
      shift
      ;;
  esac
done

if [ ${#RAW_PRDS[@]} -eq 0 ]; then
  echo "Usage: $0 [-j N] [--dry-run] <prd1> [prd2] ..."
  echo "Run '$0 --help' for more information."
  exit 1
fi

# Resolve PRD names - if just a number, find the full name via glob
resolve_prd() {
  local input="$1"

  # If it's already a full path that exists, use it
  if [ -f ".claude/prds/${input}.md" ]; then
    echo "$input"
    return 0
  fi

  # If it looks like just a number, try to glob match
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    local matches=(.claude/prds/${input}-*.md)
    if [ -f "${matches[0]}" ]; then
      # Extract just the name without path and extension
      local name="${matches[0]}"
      name="${name#.claude/prds/}"
      name="${name%.md}"
      echo "$name"
      return 0
    fi
  fi

  # Return as-is (will fail later with NOT_FOUND)
  echo "$input"
}

# Resolve all PRD names
PRDS=()
echo "Resolving PRD names..."
for raw in "${RAW_PRDS[@]}"; do
  resolved=$(resolve_prd "$raw")
  if [ "$raw" != "$resolved" ]; then
    echo "  $raw -> $resolved"
  fi
  PRDS+=("$resolved")
done
echo ""

LOGDIR=".claude/logs/batch-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOGDIR"

get_status() {
  local prd="$1"
  local file=".claude/prds/${prd}.md"
  if [ -f "$file" ]; then
    grep "^status:" "$file" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "unknown"
  else
    echo "NOT_FOUND"
  fi
}

# Analyze log to determine which phases completed
analyze_phases() {
  local logfile="$1"
  local phases=""

  # Check for phase completion indicators from prd-complete.sh
  if grep -q "Phase 1 complete" "$logfile" 2>/dev/null; then
    phases="${phases}1"
  fi
  if grep -q "Phase 2 complete" "$logfile" 2>/dev/null; then
    phases="${phases}2"
  fi
  if grep -q "Phase 3 complete" "$logfile" 2>/dev/null; then
    phases="${phases}3"
  fi
  if grep -q "Phase 4 complete" "$logfile" 2>/dev/null; then
    phases="${phases}4"
  fi
  if grep -q "Phase 5 complete" "$logfile" 2>/dev/null; then
    phases="${phases}5"
  fi
  if grep -q "Phase 6 complete\|PRD Complete:" "$logfile" 2>/dev/null; then
    phases="${phases}6"
  fi

  echo "$phases"
}

process_prd() {
  local prd="$1"
  local logfile="$LOGDIR/${prd}.log"
  local status
  status=$(get_status "$prd")

  echo "[$prd] Starting (status: $status)..."

  if [ "$status" = "complete" ]; then
    echo "SKIPPED" > "$logfile.result"
    echo "phases:skipped" > "$logfile.phases"
    echo "[$prd] Skipped (already complete)"
    return 0
  fi

  if [ "$status" = "NOT_FOUND" ]; then
    echo "NOT_FOUND" > "$logfile.result"
    echo "phases:none" > "$logfile.phases"
    echo "[$prd] Error: PRD file not found"
    return 1
  fi

  if $DRY_RUN; then
    echo "DRY_RUN" > "$logfile.result"
    echo "phases:dry" > "$logfile.phases"
    echo "[$prd] Would run: claude --dangerously-skip-permissions --print \"/pm:prd-complete $prd\""
    return 0
  fi

  # Run claude in fresh session, capture output
  echo "[$prd] Running phases..."

  if [ "$PARALLEL" = "1" ]; then
    echo ""
    bash .claude/scripts/pm/prd-complete.sh "$prd" 2>&1 | tee "$logfile"
    local exit_code=${PIPESTATUS[0]}
    echo ""
  else
    bash .claude/scripts/pm/prd-complete.sh "$prd" > "$logfile" 2>&1
    local exit_code=$?
  fi

  # Analyze which phases were reached
  local phases=$(analyze_phases "$logfile")
  echo "phases:$phases" > "$logfile.phases"

  # Check ACTUAL PRD status (not just exit code)
  local final_status=$(get_status "$prd")

  if [ "$final_status" = "complete" ]; then
    echo "SUCCESS" > "$logfile.result"
    echo "[$prd] ✓ Complete (phases: $phases)"
    return 0
  else
    # Claude returned but PRD not complete - it stopped early
    echo "INCOMPLETE:$phases" > "$logfile.result"
    echo "[$prd] ✗ Incomplete - stopped at phase(s): $phases (status still: $final_status)"
    return 1
  fi
}

export -f process_prd get_status analyze_phases
export LOGDIR DRY_RUN PARALLEL

echo "Processing ${#PRDS[@]} PRDs (parallel: $PARALLEL)"
echo "Logs: $LOGDIR"
echo ""

# Run with parallelism - continue even if some fail
printf '%s\n' "${PRDS[@]}" | xargs -P "$PARALLEL" -I {} bash -c 'process_prd "$@" || true' _ {}

# Final report
echo ""
echo "========================================"
echo "        BATCH COMPLETE"
echo "========================================"

SUCCESS=0
SKIPPED=0
FAILED=0
INCOMPLETE=0

for prd in "${PRDS[@]}"; do
  result=$(cat "$LOGDIR/${prd}.log.result" 2>/dev/null || echo "UNKNOWN")
  phases=$(cat "$LOGDIR/${prd}.log.phases" 2>/dev/null | sed 's/phases://' || echo "?")

  case "$result" in
    SUCCESS)
      echo "[OK]   $prd (phases: $phases)"
      ((SUCCESS++))
      ;;
    SKIPPED)
      echo "[SKIP] $prd (already complete)"
      ((SKIPPED++))
      ;;
    INCOMPLETE*)
      incomplete_phases=$(echo "$result" | cut -d: -f2)
      echo "[STOP] $prd (stopped at phases: $incomplete_phases)"
      ((INCOMPLETE++))
      ;;
    NOT_FOUND)
      echo "[ERR]  $prd (not found)"
      ((FAILED++))
      ;;
    DRY_RUN)
      echo "[DRY]  $prd"
      ;;
    *)
      echo "[???]  $prd (unknown: $result)"
      ((FAILED++))
      ;;
  esac
done

echo ""
echo "Success: $SUCCESS | Skipped: $SKIPPED | Incomplete: $INCOMPLETE | Failed: $FAILED"
echo "Logs: $LOGDIR"

if [ "$INCOMPLETE" -gt 0 ]; then
  echo ""
  echo "⚠️  $INCOMPLETE PRD(s) stopped early. Check logs for details."
fi

# Exit with failure if any PRD failed or incomplete
if [ "$FAILED" -gt 0 ] || [ "$INCOMPLETE" -gt 0 ]; then
  exit 1
fi

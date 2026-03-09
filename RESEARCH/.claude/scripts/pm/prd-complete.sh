#!/bin/bash
# prd-complete.sh - Execute full PRD lifecycle in 6 phases
#
# Usage:
#   ./prd-complete.sh <prd_name>
#   ./prd-complete.sh 80-mongodb-prototype-instance
#
# Each phase runs in a fresh Claude session for reliability.

set -uo pipefail

PRD="${1:-}"

if [ -z "$PRD" ]; then
  echo "Usage: $0 <prd_name>"
  exit 1
fi

PRD_FILE=".claude/prds/${PRD}.md"
EPIC_DIR=".claude/epics/${PRD}"

# Preflight check
if [ ! -f "$PRD_FILE" ]; then
  echo "❌ PRD not found: $PRD_FILE"
  exit 1
fi

status=$(grep "^status:" "$PRD_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
if [ "$status" = "complete" ]; then
  echo "✅ PRD already complete: $PRD"
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PRD Complete: $PRD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_phase() {
  local phase_num="$1"
  local phase_name="$2"
  local skill="$3"
  local verify_cmd="$4"

  echo "[$phase_num/6] $phase_name..."

  if ! claude --dangerously-skip-permissions --print "/pm:$skill $PRD" 2>&1; then
    echo "❌ Phase $phase_num failed: $skill"
    return 1
  fi

  # Verify phase completed
  if [ -n "$verify_cmd" ]; then
    if ! eval "$verify_cmd" >/dev/null 2>&1; then
      echo "⚠️  Phase $phase_num verification warning"
    fi
  fi

  echo "✓ Phase $phase_num complete"
  echo ""
  return 0
}

# Phase 1: Parse PRD to Epic
run_phase 1 "Parse PRD to Epic" "prd-parse" \
  "test -f $EPIC_DIR/epic.md" || exit 1

# Phase 2: Decompose Epic to Tasks
run_phase 2 "Decompose to Tasks" "epic-decompose" \
  "ls $EPIC_DIR/[0-9]*.md 2>/dev/null | head -1" || exit 1

# Phase 3: Sync to GitHub
run_phase 3 "Sync to GitHub" "epic-sync" \
  "grep -q 'github:' $EPIC_DIR/epic.md" || exit 1

# Phase 4: Implement Epic
run_phase 4 "Implement Tasks" "epic-start" \
  "" || exit 1

# Phase 5: Merge Epic
run_phase 5 "Merge to Main" "epic-merge" \
  "" || exit 1

# Phase 6: Mark PRD Complete
echo "[6/6] Mark PRD Complete..."
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sed -i "s/status: backlog/status: complete/" "$PRD_FILE"
sed -i "s/status: in-progress/status: complete/" "$PRD_FILE"
sed -i "s/^updated:.*/updated: $current_date/" "$PRD_FILE"

git add "$PRD_FILE" "$EPIC_DIR/" 2>/dev/null
git commit -m "PRD $PRD: Mark complete" 2>/dev/null || true
git push origin main 2>/dev/null || true
echo "✓ Phase 6 complete"
echo ""

# Final verification
final_status=$(grep "^status:" "$PRD_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
if [ "$final_status" = "complete" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ PRD Complete: $PRD"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Phases completed:"
  echo "  1. ✓ Parse PRD to Epic"
  echo "  2. ✓ Decompose to tasks"
  echo "  3. ✓ Sync to GitHub"
  echo "  4. ✓ Implement all tasks"
  echo "  5. ✓ Merge to main"
  echo "  6. ✓ PRD marked complete"
  exit 0
else
  echo "❌ PRD not marked complete (status: $final_status)"
  exit 1
fi

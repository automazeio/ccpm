#!/bin/bash
# test-pipeline-steps.sh - Test harness for pipeline-lib.sh
#
# Usage:
#   ./test-pipeline-steps.sh state              # Test state file operations
#   ./test-pipeline-steps.sh step <N>           # Test specific step pre/post checks
#   ./test-pipeline-steps.sh dry-run [session]  # Dry run full pipeline
#   ./test-pipeline-steps.sh status [session]   # Show pipeline status
#   ./test-pipeline-steps.sh reset [session]    # Reset pipeline state
#   ./test-pipeline-steps.sh all                # Run all tests
#
# Examples:
#   ./test-pipeline-steps.sh state
#   ./test-pipeline-steps.sh step 5
#   ./test-pipeline-steps.sh dry-run my-app
#   ./test-pipeline-steps.sh status my-app

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the pipeline library
source "$SCRIPT_DIR/pipeline-lib.sh"

# Test session name
TEST_SESSION="${2:-test-session-$(date +%s)}"

# ============================================================
# Test Functions
# ============================================================

# Test state file operations
test_state_operations() {
  echo "=== Testing State File Operations ==="
  echo ""

  local test_dir=".claude/pipeline/test-state-$$"
  local test_file="$test_dir/state.yaml"

  # Initialize state
  echo "1. Testing init_pipeline_state..."
  PIPELINE_SESSION="test-state-$$"
  PIPELINE_STATE_DIR="$test_dir"
  PIPELINE_STATE_FILE="$test_file"
  mkdir -p "$test_dir"

  # Create test state file
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$test_file" << EOF
---
session: test-state-$$
status: pending
current_step: 0
last_completed_step: 0
started: $now
updated: $now
steps:
  1: {name: services, status: pending}
  2: {name: schema, status: pending}
  3: {name: repo, status: pending}
  4: {name: interrogate, status: pending}
  5: {name: extract, status: pending}
  6: {name: credentials, status: pending}
  7: {name: roadmap, status: pending}
  8: {name: decompose, status: pending}
  9: {name: batch, status: pending}
  10: {name: synthetic, status: pending}
  11: {name: remediation, status: pending}
errors: []
warnings: []
---
EOF
  echo "   ✓ State file created"

  # Test get_step_status
  echo "2. Testing get_step_status..."
  local status
  status=$(get_step_status 1)
  if [ "$status" = "pending" ]; then
    echo "   ✓ Step 1 status: pending"
  else
    echo "   ✗ Expected 'pending', got '$status'"
  fi

  # Test update_step_status
  echo "3. Testing update_step_status..."
  update_step_status 1 "running"
  status=$(get_step_status 1)
  if [ "$status" = "running" ]; then
    echo "   ✓ Step 1 updated to running"
  else
    echo "   ✗ Expected 'running', got '$status'"
  fi

  # Test current_step update
  echo "4. Testing get_current_step..."
  local current
  current=$(get_current_step)
  if [ "$current" = "1" ]; then
    echo "   ✓ Current step: 1"
  else
    echo "   ✗ Expected '1', got '$current'"
  fi

  # Test completing a step
  echo "5. Testing step completion..."
  update_step_status 1 "complete"
  local last
  last=$(get_last_completed_step)
  if [ "$last" = "1" ]; then
    echo "   ✓ Last completed step: 1"
  else
    echo "   ✗ Expected '1', got '$last'"
  fi

  # Test pipeline status
  echo "6. Testing get_pipeline_status..."
  local pipe_status
  pipe_status=$(get_pipeline_status)
  if [ "$pipe_status" = "in_progress" ]; then
    echo "   ✓ Pipeline status: in_progress"
  else
    echo "   ✗ Expected 'in_progress', got '$pipe_status'"
  fi

  # Cleanup
  rm -rf "$test_dir"
  echo ""
  echo "State operations tests complete ✓"
  echo ""
}

# Test a specific step's pre/post checks
test_step() {
  local step_num="$1"

  if [ -z "$step_num" ] || [ "$step_num" -lt 1 ] || [ "$step_num" -gt 12 ]; then
    echo "❌ Invalid step number: $step_num (must be 1-12)"
    exit 1
  fi

  local step_info="${PIPELINE_STEPS[$((step_num-1))]}"
  local step_name
  local step_desc
  step_name=$(echo "$step_info" | cut -d: -f1)
  step_desc=$(echo "$step_info" | cut -d: -f2)

  echo "=== Testing Step $step_num: $step_desc ==="
  echo ""

  # Initialize state for testing
  init_pipeline_state "$TEST_SESSION"

  echo "Pre-check function: precheck_step_$step_num"
  echo "---"

  local precheck_func="precheck_step_$step_num"
  if $precheck_func 2>&1; then
    echo "---"
    echo "Pre-check: PASS ✓"
  else
    echo "---"
    echo "Pre-check: FAIL ✗"
  fi

  echo ""
  echo "Post-check function: postcheck_step_$step_num"
  echo "---"

  local postcheck_func="postcheck_step_$step_num"
  if $postcheck_func 2>&1; then
    echo "---"
    echo "Post-check: PASS ✓"
  else
    echo "---"
    echo "Post-check: FAIL ✗"
  fi

  echo ""
  echo "Can skip: $([ "$step_num" = "2" ] || [ "$step_num" = "6" ] && echo "Yes" || echo "No")"
  echo ""
}

# Dry run the full pipeline (only checks, no execution)
dry_run_pipeline() {
  local session="${1:-$TEST_SESSION}"

  echo "=== Dry Run Pipeline: $session ==="
  echo ""
  echo "This will test all pre-checks without executing steps."
  echo ""

  # Initialize state
  init_pipeline_state "$session"

  local passed=0
  local failed=0
  local skippable=0

  for i in {1..12}; do
    local step_info="${PIPELINE_STEPS[$((i-1))]}"
    local step_name
    local step_desc
    step_name=$(echo "$step_info" | cut -d: -f1)
    step_desc=$(echo "$step_info" | cut -d: -f2)

    local can_skip=""
    if [ "$i" = "2" ] || [ "$i" = "6" ]; then
      can_skip=" (optional)"
    fi

    printf "%2d. %-35s " "$i" "$step_desc$can_skip"

    local precheck_func="precheck_step_$i"
    if $precheck_func >/dev/null 2>&1; then
      echo "✓ ready"
      ((passed++))
    else
      if [ "$i" = "2" ] || [ "$i" = "6" ]; then
        echo "⊘ skip"
        ((skippable++))
      else
        echo "✗ blocked"
        ((failed++))
      fi
    fi
  done

  echo ""
  echo "Summary:"
  echo "  Ready:    $passed"
  echo "  Blocked:  $failed"
  echo "  Skippable: $skippable"
  echo ""

  if [ "$failed" -gt 0 ]; then
    echo "Pipeline cannot proceed: $failed required step(s) blocked"
    return 1
  else
    echo "Pipeline ready to run"
    return 0
  fi
}

# Show pipeline status
show_status() {
  local session="${1:-$TEST_SESSION}"

  # Initialize to load state
  init_pipeline_state "$session"

  # Show status using library function
  show_pipeline_status
}

# Reset pipeline state
reset_pipeline() {
  local session="${1:-$TEST_SESSION}"
  local state_dir=".claude/pipeline/$session"

  if [ -d "$state_dir" ]; then
    echo "Removing pipeline state: $state_dir"
    rm -rf "$state_dir"
    echo "Pipeline state reset ✓"
  else
    echo "No pipeline state found for: $session"
  fi
}

# Test all pre/post checks
test_all_checks() {
  echo "=== Testing All Step Checks ==="
  echo ""

  # Initialize state for testing
  init_pipeline_state "$TEST_SESSION"

  echo "Pre-checks:"
  echo "-----------"
  for i in {1..12}; do
    local step_info="${PIPELINE_STEPS[$((i-1))]}"
    local step_name
    step_name=$(echo "$step_info" | cut -d: -f1)

    local precheck_func="precheck_step_$i"
    printf "%2d. %-15s " "$i" "$step_name"

    if $precheck_func >/dev/null 2>&1; then
      echo "✓"
    else
      local msg
      msg=$($precheck_func 2>&1 || true)
      echo "✗ $msg"
    fi
  done

  echo ""
  echo "Post-checks:"
  echo "------------"
  for i in {1..12}; do
    local step_info="${PIPELINE_STEPS[$((i-1))]}"
    local step_name
    step_name=$(echo "$step_info" | cut -d: -f1)

    local postcheck_func="postcheck_step_$i"
    printf "%2d. %-15s " "$i" "$step_name"

    if $postcheck_func >/dev/null 2>&1; then
      echo "✓"
    else
      local msg
      msg=$($postcheck_func 2>&1 || true)
      echo "✗ $msg"
    fi
  done

  echo ""
}

# Run all tests
run_all_tests() {
  echo "=== Running All Pipeline Tests ==="
  echo ""

  echo "--- State Operations ---"
  test_state_operations

  echo "--- All Checks ---"
  test_all_checks

  echo ""
  echo "All tests complete ✓"
}

# ============================================================
# Help
# ============================================================

show_help() {
  cat << 'EOF'
Pipeline Test Harness

Usage:
  ./test-pipeline-steps.sh state              Test state file operations
  ./test-pipeline-steps.sh step <N>           Test specific step (1-11)
  ./test-pipeline-steps.sh dry-run [session]  Dry run pipeline checks
  ./test-pipeline-steps.sh status [session]   Show pipeline status
  ./test-pipeline-steps.sh reset [session]    Reset pipeline state
  ./test-pipeline-steps.sh checks             Test all pre/post checks
  ./test-pipeline-steps.sh all                Run all tests
  ./test-pipeline-steps.sh help               Show this help

Steps:
   1. services      Setup Infrastructure Services
   2. schema        Create Database Schema (optional)
   3. repo          Ensure GitHub Repository
   4. interrogate   Run Structured Q&A
   5. extract       Extract Scope Document
   6. credentials   Gather Credentials (optional)
   7. roadmap       Generate MVP Roadmap
   8. decompose     Decompose into PRDs
   9. batch         Batch Process PRDs
  10. deploy        Deploy to Kubernetes
  11. synthetic     Synthetic Persona Testing
  12. remediation   Generate Remediation PRDs

Examples:
  ./test-pipeline-steps.sh step 5           # Test step 5 (extract)
  ./test-pipeline-steps.sh dry-run my-app   # Check if pipeline can run
  ./test-pipeline-steps.sh status my-app    # Show current progress
EOF
}

# ============================================================
# Main
# ============================================================

case "${1:-help}" in
  state)
    test_state_operations
    ;;
  step)
    test_step "$2"
    ;;
  dry-run)
    dry_run_pipeline "$2"
    ;;
  status)
    show_status "$2"
    ;;
  reset)
    reset_pipeline "$2"
    ;;
  checks)
    test_all_checks
    ;;
  all)
    run_all_tests
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    echo ""
    show_help
    exit 1
    ;;
esac

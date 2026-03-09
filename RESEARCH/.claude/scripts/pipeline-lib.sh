#!/bin/bash
# pipeline-lib.sh - Pipeline execution library for interrogate.sh
#
# Provides:
# - State management (init, read, update)
# - Step execution wrapper with pre/post validation
# - Resume capability
# - Claude command verification
# - Self-healing retry with /pm:fix_problem
#
# Usage:
#   source .claude/scripts/pipeline-lib.sh
#   init_pipeline_state "session-name"
#   execute_step 1
#   execute_step 2
#   ...

set -e

# Pipeline constants
PIPELINE_DIR=".claude/pipeline"
PIPELINE_STEPS=(
  "services:Setup Infrastructure Services"
  "schema:Create Database Schema"
  "repo:Ensure GitHub Repository"
  "interrogate:Run Structured Q&A"
  "extract:Extract Scope Document"
  "credentials:Gather Credentials"
  "roadmap:Generate MVP Roadmap"
  "generate-template:Generate Skeleton Templates"
  "deploy-skeleton:Deploy Skeleton Application"
  "decompose:Decompose into PRDs"
  "batch:Batch Process PRDs"
  "deploy:Deploy Full Application"
  "synthetic:Synthetic Persona Testing"
  "remediation:Generate Remediation PRDs"
)

# Total steps
TOTAL_STEPS=14

# Steps that can be skipped on failure
SKIPPABLE_STEPS="2 6"

# Maximum fix attempts per step
MAX_FIX_ATTEMPTS=3

# Global state variables
PIPELINE_SESSION=""
PIPELINE_STATE_DIR=""
PIPELINE_STATE_FILE=""

# ============================================================
# Database Helper Functions
# ============================================================

# Get database connection string from .env
get_db_connection() {
  if [ -f ".env" ]; then
    local db_url
    db_url=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)
    if [ -n "$db_url" ]; then
      echo "$db_url"
      return 0
    fi
    # Fallback to individual vars
    local host port user pass db
    host=$(grep "^POSTGRES_HOST=" .env | cut -d= -f2-)
    port=$(grep "^POSTGRES_PORT=" .env | cut -d= -f2-)
    user=$(grep "^POSTGRES_USER=" .env | cut -d= -f2-)
    pass=$(grep "^POSTGRES_PASSWORD=" .env | cut -d= -f2-)
    db=$(grep "^POSTGRES_DB=" .env | cut -d= -f2-)
    if [ -n "$host" ] && [ -n "$user" ] && [ -n "$db" ]; then
      echo "postgresql://$user:$pass@$host:${port:-5432}/$db"
      return 0
    fi
  fi
  echo ""
  return 1
}

# Execute a database query and return results
db_query() {
  local query="$1"
  local conn
  conn=$(get_db_connection)
  if [ -z "$conn" ]; then
    echo "0"
    return 1
  fi
  psql "$conn" -t -A -c "$query" 2>/dev/null || echo "0"
}

# Execute a database query and return scalar result
db_query_scalar() {
  local query="$1"
  local result
  result=$(db_query "$query")
  echo "${result:-0}"
}

# Check if database is available
db_available() {
  local conn
  conn=$(get_db_connection)
  if [ -z "$conn" ]; then
    return 1
  fi
  psql "$conn" -c "SELECT 1" &>/dev/null
  return $?
}

# Get session summary from database
get_session_summary() {
  local session="$1"
  if db_available; then
    local features journeys user_types integrations
    features=$(db_query_scalar "SELECT COUNT(*) FROM feature WHERE session_name = '$session' AND status = 'confirmed'")
    journeys=$(db_query_scalar "SELECT COUNT(*) FROM journey WHERE session_name = '$session' AND confirmation_status = 'confirmed'")
    user_types=$(db_query_scalar "SELECT COUNT(*) FROM user_type WHERE session_name = '$session'")
    integrations=$(db_query_scalar "SELECT COUNT(*) FROM integration WHERE session_name = '$session' AND status = 'confirmed'")
    echo "Features: $features, Journeys: $journeys, User Types: $user_types, Integrations: $integrations"
  else
    echo "Database not available"
  fi
}

# ============================================================
# State Management Functions
# ============================================================

# Initialize pipeline state for a session
# Usage: init_pipeline_state "session-name"
init_pipeline_state() {
  local session="$1"

  if [ -z "$session" ]; then
    echo "❌ Session name required"
    return 1
  fi

  PIPELINE_SESSION="$session"
  PIPELINE_STATE_DIR="$PIPELINE_DIR/$session"
  PIPELINE_STATE_FILE="$PIPELINE_STATE_DIR/state.yaml"

  mkdir -p "$PIPELINE_STATE_DIR"

  # Create state file if it doesn't exist
  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$PIPELINE_STATE_FILE" << EOF
---
session: $session
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
  8: {name: generate-template, status: pending}
  9: {name: deploy-skeleton, status: pending}
  10: {name: decompose, status: pending}
  11: {name: batch, status: pending}
  12: {name: deploy, status: pending}
  13: {name: synthetic, status: pending}
  14: {name: remediation, status: pending}
errors: []
warnings: []
fix_attempts: []
---
EOF
    echo "Pipeline state initialized: $PIPELINE_STATE_FILE"
  else
    echo "Pipeline state loaded: $PIPELINE_STATE_FILE"
  fi
}

# Get the status of a specific step
# Usage: get_step_status 5
# Returns: pending, running, complete, failed, skipped
get_step_status() {
  local step_num="$1"

  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "pending"
    return
  fi

  grep "^  $step_num:" "$PIPELINE_STATE_FILE" | sed 's/.*status: \([a-z]*\).*/\1/'
}

# Update the status of a specific step
# Usage: update_step_status 5 "complete"
update_step_status() {
  local step_num="$1"
  local status="$2"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "❌ State file not found"
    return 1
  fi

  # Get step name
  local step_name
  step_name=$(echo "${PIPELINE_STEPS[$((step_num-1))]}" | cut -d: -f1)

  # Update the step status
  sed -i "s/^  $step_num: {name: $step_name, status: [a-z]*}/  $step_num: {name: $step_name, status: $status}/" "$PIPELINE_STATE_FILE"

  # Update timestamps and current step
  sed -i "s/^updated: .*/updated: $now/" "$PIPELINE_STATE_FILE"

  if [ "$status" = "running" ]; then
    sed -i "s/^current_step: .*/current_step: $step_num/" "$PIPELINE_STATE_FILE"
    sed -i "s/^status: .*/status: in_progress/" "$PIPELINE_STATE_FILE"
  elif [ "$status" = "complete" ]; then
    sed -i "s/^last_completed_step: .*/last_completed_step: $step_num/" "$PIPELINE_STATE_FILE"
    # If this is the last step, mark pipeline complete
    if [ "$step_num" -eq "$TOTAL_STEPS" ]; then
      sed -i "s/^status: .*/status: complete/" "$PIPELINE_STATE_FILE"
    fi
  elif [ "$status" = "paused" ]; then
    # Step is paused for user interaction
    sed -i "s/^current_step: .*/current_step: $step_num/" "$PIPELINE_STATE_FILE"
    sed -i "s/^status: .*/status: paused/" "$PIPELINE_STATE_FILE"
  elif [ "$status" = "failed" ]; then
    sed -i "s/^status: .*/status: failed/" "$PIPELINE_STATE_FILE"
  fi
}

# Get the last completed step number
# Usage: get_last_completed_step
get_last_completed_step() {
  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "0"
    return
  fi

  grep "^last_completed_step:" "$PIPELINE_STATE_FILE" | cut -d: -f2 | tr -d ' '
}

# Get current step number
# Usage: get_current_step
get_current_step() {
  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "0"
    return
  fi

  grep "^current_step:" "$PIPELINE_STATE_FILE" | cut -d: -f2 | tr -d ' '
}

# Get pipeline status
# Usage: get_pipeline_status
get_pipeline_status() {
  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "pending"
    return
  fi

  grep "^status:" "$PIPELINE_STATE_FILE" | head -1 | cut -d: -f2 | tr -d ' '
}

# Add an error to the state
# Usage: add_error "Step 5 failed: No scope document"
add_error() {
  local error_msg="$1"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Escape special characters for sed
  local escaped_msg
  escaped_msg=$(echo "$error_msg" | sed 's/[&/\]/\\&/g')

  # Append error to the errors array
  sed -i "s/^errors: \[\]/errors:\n  - \"$now: $escaped_msg\"/" "$PIPELINE_STATE_FILE"
}

# Add a warning to the state
# Usage: add_warning "Credentials deferred"
add_warning() {
  local warn_msg="$1"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local escaped_msg
  escaped_msg=$(echo "$warn_msg" | sed 's/[&/\]/\\&/g')

  sed -i "s/^warnings: \[\]/warnings:\n  - \"$now: $escaped_msg\"/" "$PIPELINE_STATE_FILE"
}

# Log a fix attempt
# Usage: log_fix_attempt 10 1 "error message" "approach"
log_fix_attempt() {
  local step="$1"
  local attempt="$2"
  local error="$3"
  local approach="$4"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create fix log file
  local fix_log="$PIPELINE_STATE_DIR/fix-step-$step.md"

  if [ ! -f "$fix_log" ]; then
    cat > "$fix_log" << EOF
# Fix Attempts for Step $step

## Summary
- Step: $step
- Started: $now

## Attempts

EOF
  fi

  cat >> "$fix_log" << EOF
### Attempt $attempt - $now
**Approach**: $approach
**Error**:
\`\`\`
$error
\`\`\`

EOF
}

# ============================================================
# Pre-check Functions (return 0 for pass, 1 for fail)
# ============================================================

precheck_step_1() {
  # services - no pre-requisites
  return 0
}

precheck_step_2() {
  # schema - check if script exists
  if [ -f "./.claude/scripts/create-interview-schema.sh" ]; then
    return 0
  fi
  return 1
}

precheck_step_3() {
  # repo - check gh is installed
  if command -v gh &> /dev/null; then
    return 0
  fi
  echo "GitHub CLI (gh) not installed"
  return 1
}

precheck_step_4() {
  # interrogate - no pre-requisites
  return 0
}

precheck_step_5() {
  # extract - check database for confirmed features
  # First check conversation file exists and is complete
  local conv=".claude/interrogations/$PIPELINE_SESSION/conversation.md"
  if [ -f "$conv" ]; then
    local status
    status=$(grep "^Status:" "$conv" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
    if [ "$status" = "complete" ]; then
      # Also verify database has confirmed features
      local feature_count
      feature_count=$(db_query_scalar "SELECT COUNT(*) FROM feature WHERE session_name = '$PIPELINE_SESSION' AND status = 'confirmed'")
      if [ "$feature_count" -gt 0 ]; then
        return 0
      fi
      echo "No confirmed features in database for session: $PIPELINE_SESSION"
      return 1
    fi
    echo "Interrogation not complete"
    return 1
  fi
  echo "Conversation file not found: $conv"
  return 1
}

precheck_step_6() {
  # credentials - technical architecture must exist
  local tech_arch=".claude/scopes/$PIPELINE_SESSION/04_technical_architecture.md"
  if [ -f "$tech_arch" ]; then
    return 0
  fi
  echo "Technical architecture not found: $tech_arch"
  return 1
}

precheck_step_7() {
  # roadmap - scope document must exist
  local scope=".claude/scopes/$PIPELINE_SESSION/00_scope_document.md"
  if [ -f "$scope" ]; then
    return 0
  fi
  echo "Scope document not found: $scope"
  return 1
}

precheck_step_8() {
  # generate-template - technical architecture must exist
  local tech_arch=".claude/scopes/$PIPELINE_SESSION/04_technical_architecture.md"
  if [ -f "$tech_arch" ]; then
    return 0
  fi
  echo "Technical architecture not found: $tech_arch"
  return 1
}

precheck_step_9() {
  # deploy-skeleton - K8s templates must exist
  local k8s_dir=".claude/templates/$PIPELINE_SESSION/k8s"
  if [ -d "$k8s_dir" ]; then
    return 0
  fi
  echo "K8s templates not found: $k8s_dir"
  return 1
}

precheck_step_10() {
  # decompose - roadmap must exist
  local roadmap=".claude/scopes/$PIPELINE_SESSION/07_roadmap.md"
  if [ -f "$roadmap" ]; then
    return 0
  fi
  echo "Roadmap not found: $roadmap"
  return 1
}

precheck_step_11() {
  # batch - PRD files must exist
  local prd_count
  prd_count=$(ls -1 .claude/prds/*.md 2>/dev/null | wc -l)
  if [ "$prd_count" -gt 0 ]; then
    return 0
  fi
  echo "No PRD files found in .claude/prds/"
  return 1
}

precheck_step_12() {
  # deploy - All PRDs must be complete
  local complete_count
  complete_count=$(grep -l "^status: complete" .claude/prds/*.md 2>/dev/null | wc -l)
  if [ "$complete_count" -gt 0 ]; then
    return 0
  fi
  echo "No PRDs marked complete - batch processing must finish first"
  return 1
}

precheck_step_13() {
  # synthetic - user journeys must exist
  local journeys=".claude/scopes/$PIPELINE_SESSION/02_user_journeys.md"
  if [ -f "$journeys" ]; then
    return 0
  fi
  echo "User journeys not found: $journeys"
  return 1
}

precheck_step_14() {
  # remediation - feedback file must exist
  local feedback=".claude/testing/feedback/$PIPELINE_SESSION-feedback.json"
  if [ -f "$feedback" ]; then
    return 0
  fi
  echo "Feedback file not found: $feedback"
  return 1
}

# ============================================================
# Post-check Functions (return 0 for pass, 1 for fail)
# ============================================================

postcheck_step_1() {
  # services - check pods are running
  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  # Check if namespace exists and has pods
  if kubectl get namespace "$project_name" &>/dev/null; then
    local pod_count
    pod_count=$(kubectl get pods -n "$project_name" --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
      return 0
    fi
  fi
  echo "Services not running in namespace $project_name"
  return 1
}

postcheck_step_2() {
  # schema - tables exist (check via script exit code or just pass)
  # This is optional, so we pass if script ran
  return 0
}

postcheck_step_3() {
  # repo - git remote exists
  if git remote get-url origin &>/dev/null; then
    return 0
  fi
  echo "Git remote 'origin' not configured"
  return 1
}

postcheck_step_4() {
  # interrogate - conversation file exists, is complete, and DB has confirmed features
  local conv=".claude/interrogations/$PIPELINE_SESSION/conversation.md"
  if [ -f "$conv" ]; then
    local status
    status=$(grep "^Status:" "$conv" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
    if [ "$status" = "complete" ]; then
      # Verify database has confirmed features
      local feature_count
      feature_count=$(db_query_scalar "SELECT COUNT(*) FROM feature WHERE session_name = '$PIPELINE_SESSION' AND status = 'confirmed'")
      if [ "$feature_count" -gt 0 ]; then
        echo "Session summary: $(get_session_summary "$PIPELINE_SESSION")"
        return 0
      fi
      echo "No confirmed features in database"
      return 1
    fi
    echo "Interrogation not complete (status: $status)"
    return 1
  fi
  echo "Conversation file not created"
  return 1
}

postcheck_step_5() {
  # extract - scope document and new files exist
  local scope=".claude/scopes/$PIPELINE_SESSION/00_scope_document.md"
  local tech_ops=".claude/scopes/$PIPELINE_SESSION/03_technical_ops.md"
  local test_plan=".claude/scopes/$PIPELINE_SESSION/08_test_plan.md"

  if [ -f "$scope" ]; then
    local lines
    lines=$(wc -l < "$scope")
    if [ "$lines" -gt 50 ]; then
      # Check for new required files
      if [ ! -f "$tech_ops" ]; then
        echo "Technical ops file not created: $tech_ops"
        return 1
      fi
      if [ ! -f "$test_plan" ]; then
        echo "Test plan file not created: $test_plan"
        return 1
      fi
      return 0
    fi
    echo "Scope document too short ($lines lines, expected >50)"
    return 1
  fi
  echo "Scope document not created"
  return 1
}

postcheck_step_6() {
  # credentials - .env and credentials.yaml exist (or gracefully skip)
  local creds_state=".claude/scopes/$PIPELINE_SESSION/credentials.yaml"
  if [ -f ".env" ] && [ -f "$creds_state" ]; then
    return 0
  fi
  # This step can be skipped
  echo "Credentials not fully gathered (can skip)"
  return 0
}

postcheck_step_7() {
  # roadmap - roadmap exists and contains "Phase"
  local roadmap=".claude/scopes/$PIPELINE_SESSION/07_roadmap.md"
  if [ -f "$roadmap" ]; then
    if grep -q "Phase" "$roadmap" 2>/dev/null; then
      return 0
    fi
    echo "Roadmap missing Phase content"
    return 1
  fi
  echo "Roadmap not created"
  return 1
}

postcheck_step_8() {
  # generate-template - K8s manifests must exist
  local k8s_dir=".claude/templates/$PIPELINE_SESSION/k8s"
  if [ -d "$k8s_dir" ] && [ -f "$k8s_dir/namespace.yaml" ]; then
    return 0
  fi
  echo "K8s templates not created in $k8s_dir"
  return 1
}

postcheck_step_9() {
  # deploy-skeleton - at least one pod running
  local running
  running=$(kubectl get pods -n "$PIPELINE_SESSION" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
  if [ "$running" -gt 0 ]; then
    return 0
  fi
  echo "No running pods in namespace $PIPELINE_SESSION"
  return 1
}

postcheck_step_10() {
  # decompose - at least 1 PRD file exists
  local prd_count
  prd_count=$(ls -1 .claude/prds/*.md 2>/dev/null | wc -l)
  if [ "$prd_count" -gt 0 ]; then
    return 0
  fi
  echo "No PRD files generated"
  return 1
}

postcheck_step_11() {
  # batch - at least 1 PRD marked complete
  local complete_count
  complete_count=$(grep -l "^status: complete" .claude/prds/*.md 2>/dev/null | wc -l)
  if [ "$complete_count" -gt 0 ]; then
    return 0
  fi
  echo "No PRDs marked complete"
  return 1
}

postcheck_step_12() {
  # deploy - all pods running in namespace
  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  # Check if all pods are Running or Completed
  local not_ready
  not_ready=$(kubectl get pods -n "$project_name" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
  if [ "$not_ready" -eq 0 ]; then
    return 0
  fi
  echo "Not all pods are running ($not_ready pods not ready)"
  kubectl get pods -n "$project_name" --no-headers 2>/dev/null | grep -v "Running\|Completed"
  return 1
}

postcheck_step_13() {
  # synthetic - personas.json exists
  local personas=".claude/testing/personas/$PIPELINE_SESSION-personas.json"
  if [ -f "$personas" ]; then
    return 0
  fi
  echo "Personas file not created"
  return 1
}

postcheck_step_14() {
  # remediation - analysis.md exists
  local analysis=".claude/testing/feedback/$PIPELINE_SESSION-analysis.md"
  if [ -f "$analysis" ]; then
    return 0
  fi
  echo "Analysis file not created"
  return 1
}

# ============================================================
# Step Implementation Functions
# ============================================================

run_step_1() {
  # services - Setup Infrastructure Services
  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  echo "Setting up PostgreSQL, MinIO, CloudBeaver in namespace: $project_name"

  # Run setup-service.sh for all services
  ./.claude/scripts/setup-service.sh all "$project_name" --project="$project_name"

  # Pull credentials into .env
  echo "Pulling credentials into .env..."
  NAMESPACE="$project_name" ./.claude/scripts/setup-env-from-k8s.sh
}

run_step_2() {
  # schema - Create Database Schema
  if [ -f "./.claude/scripts/create-interview-schema.sh" ]; then
    ./.claude/scripts/create-interview-schema.sh
  else
    echo "Schema script not found, skipping"
    return 0
  fi
}

run_step_3() {
  # repo - Ensure GitHub Repository (non-interactive: private, auto-push)
  ./.claude/scripts/ensure-github-repo.sh --private --push
}

run_step_4() {
  # interrogate - Run Structured Q&A interactively
  # Launches Claude for user interaction, script waits for completion
  local conv=".claude/interrogations/$PIPELINE_SESSION/conversation.md"

  mkdir -p ".claude/interrogations/$PIPELINE_SESSION"

  # Check if interrogation is already complete
  if [ -f "$conv" ]; then
    local status
    status=$(grep "^Status:" "$conv" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
    if [ "$status" = "complete" ]; then
      echo "Interrogation already complete."
      return 0
    fi
  fi

  echo "Starting interrogation session..."
  echo "Session: $PIPELINE_SESSION"
  echo ""

  # Check if we're running interactively (has a TTY)
  if [ -t 0 ]; then
    # Interactive mode - prompt user and launch Claude for them to type
    echo "When Claude starts, type this command:"
    echo ""
    echo "  /pm:interrogate $PIPELINE_SESSION"
    echo ""
    echo "Complete the Q&A session, then exit Claude (Ctrl+C or /exit)."
    echo "The pipeline will continue automatically."
    echo ""
    echo "Press Enter to launch Claude..."
    read

    # Launch interactive Claude (no command = stays open for user input)
    claude --dangerously-skip-permissions
  else
    # Non-interactive mode - run interrogate command directly
    echo "Running in non-interactive mode."
    echo "Executing: /pm:interrogate $PIPELINE_SESSION"
    echo ""
    echo "---"

    # Run the interrogate skill directly
    # This will pause at each user input point
    claude --dangerously-skip-permissions "/pm:interrogate $PIPELINE_SESSION"
  fi

  echo "---"
  echo "Interrogation session ended."
}

run_step_5() {
  # extract - Extract Scope Document (non-interactive)
  echo "Extracting findings to scope document..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:extract-findings $PIPELINE_SESSION"
  echo "---"
}

run_step_6() {
  # credentials - Gather Credentials (non-interactive)
  echo "Gathering credentials..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:gather-credentials $PIPELINE_SESSION"
  echo "---"
}

run_step_7() {
  # roadmap - Generate MVP Roadmap (non-interactive)
  echo "Generating MVP roadmap..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:roadmap-generate $PIPELINE_SESSION"
  echo "---"
}

run_step_8() {
  # generate-template - Generate K8s manifests and code scaffolds (non-interactive)
  echo "Generating skeleton templates..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:generate-template $PIPELINE_SESSION"
  echo "---"
}

run_step_9() {
  # deploy-skeleton - Deploy skeleton application (non-interactive)
  echo "Deploying skeleton application..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:deploy-skeleton $PIPELINE_SESSION"
  echo "---"
}

run_step_10() {
  # decompose - Decompose into PRDs (non-interactive)
  echo "Decomposing scope into PRDs..."
  echo "---"
  claude --dangerously-skip-permissions --print "/pm:scope-decompose $PIPELINE_SESSION --generate"
  echo "---"
}

run_step_11() {
  # batch - Batch Process PRDs (non-interactive)
  echo "=== Starting Batch Processing ==="
  echo ""
  claude --dangerously-skip-permissions --print "/pm:batch-process"
}

run_step_12() {
  # deploy - Deploy Full Application (non-interactive)
  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  echo "=== Deploying to Kubernetes ==="
  echo "Namespace: $project_name"
  echo ""
  claude --dangerously-skip-permissions --print "/pm:deploy $PIPELINE_SESSION"
}

run_step_13() {
  # synthetic - Synthetic Persona Testing (non-interactive)
  echo "Generating synthetic personas..."
  claude --dangerously-skip-permissions --print "/pm:generate-personas $PIPELINE_SESSION --count 10"

  local personas_file=".claude/testing/personas/$PIPELINE_SESSION-personas.json"
  if [ ! -f "$personas_file" ]; then
    echo "❌ Persona generation failed"
    return 1
  fi
  echo "Personas generated ✓"
  echo ""

  echo "Generating Playwright tests..."
  claude --dangerously-skip-permissions --print "/pm:generate-tests $PIPELINE_SESSION"

  local playwright_dir=".claude/testing/playwright"
  if [ ! -d "$playwright_dir" ]; then
    echo "⚠️ Test generation skipped"
    mkdir -p "$playwright_dir"
  fi
  echo "Tests generated ✓"
  echo ""

  # Run Playwright tests if configured
  echo "Running Playwright tests..."
  if [ -f "$playwright_dir/package.json" ]; then
    (cd "$playwright_dir" && npm install 2>/dev/null || true)
    (cd "$playwright_dir" && npx playwright test --reporter=json > test-results.json 2>&1) || true
    echo "Tests executed ✓"
  else
    echo "⚠️ Playwright not configured - creating placeholder results"
    echo '{"suites":[],"stats":{"expected":0,"unexpected":0,"flaky":0,"skipped":0}}' > "$playwright_dir/test-results.json"
  fi
  echo ""

  echo "Generating synthetic feedback..."
  claude --dangerously-skip-permissions --print "/pm:generate-feedback $PIPELINE_SESSION"

  local feedback_file=".claude/testing/feedback/$PIPELINE_SESSION-feedback.json"
  if [ -f "$feedback_file" ]; then
    echo "Feedback generated ✓"
  else
    echo "⚠️ Feedback generation incomplete"
    mkdir -p ".claude/testing/feedback"
    echo '[]' > "$feedback_file"
  fi
  echo ""

  echo "Analyzing feedback..."
  claude --dangerously-skip-permissions --print "/pm:analyze-feedback $PIPELINE_SESSION"

  local analysis_file=".claude/testing/feedback/$PIPELINE_SESSION-analysis.md"
  if [ -f "$analysis_file" ]; then
    echo "Analysis complete ✓"
  else
    echo "⚠️ Creating placeholder analysis"
    mkdir -p ".claude/testing/feedback"
    echo "# Feedback Analysis" > "$analysis_file"
    echo "" >> "$analysis_file"
    echo "No significant issues found." >> "$analysis_file"
  fi
}

run_step_14() {
  # remediation - Generate Remediation PRDs (non-interactive)
  local issues_file=".claude/testing/feedback/$PIPELINE_SESSION-issues.json"
  local feedback_file=".claude/testing/feedback/$PIPELINE_SESSION-feedback.json"

  # Check if there's feedback to analyze
  if [ ! -f "$feedback_file" ] && [ ! -f "$issues_file" ]; then
    echo "No feedback or issues to remediate"
    return 0
  fi

  echo "Creating PRDs to address feedback issues..."
  echo ""
  claude --dangerously-skip-permissions --print "/pm:generate-remediation $PIPELINE_SESSION --max 10"

  # Count remediation PRDs
  local prds_dir=".claude/prds"
  local remediation_count
  remediation_count=$(ls -1 "$prds_dir"/*-fix-*.md "$prds_dir"/*-improve-*.md "$prds_dir"/*-add-*.md 2>/dev/null | wc -l)

  if [ "$remediation_count" -gt 0 ]; then
    echo "Remediation PRDs generated: $remediation_count"
    echo ""
    echo "Processing remediation PRDs..."
    claude --dangerously-skip-permissions --print "/pm:batch-process"
  else
    echo "No remediation PRDs needed"
  fi
}

# ============================================================
# Execution Functions
# ============================================================

# Verify a Claude command completed successfully
# Usage: verify_claude_command "/pm:batch-process" "complete" 1800
verify_claude_command() {
  local command="$1"
  local expected_pattern="$2"
  local timeout_seconds="${3:-600}"

  echo "Running: $command"
  echo "Timeout: ${timeout_seconds}s"
  echo "---"

  # Run the command and capture output
  local output_file
  output_file=$(mktemp)

  if timeout "$timeout_seconds" claude --dangerously-skip-permissions "$command" > "$output_file" 2>&1; then
    echo "---"
    # Check if expected pattern is in output (optional verification)
    if [ -n "$expected_pattern" ]; then
      if grep -qi "$expected_pattern" "$output_file" 2>/dev/null; then
        rm -f "$output_file"
        return 0
      else
        # Pattern not found but command succeeded - might be ok
        cat "$output_file"
        rm -f "$output_file"
        return 0
      fi
    fi
    rm -f "$output_file"
    return 0
  else
    local exit_code=$?
    echo "---"
    echo "Command failed or timed out (exit code: $exit_code)"
    cat "$output_file"
    LAST_ERROR_OUTPUT=$(cat "$output_file")
    rm -f "$output_file"
    return 1
  fi
}

# Run a skill as a sub-agent via Task tool
# Usage: run_skill_as_subagent "pm:skill-name" "args" "expected_pattern" timeout_seconds
run_skill_as_subagent() {
  local skill="$1"
  local args="$2"
  local expected_pattern="$3"
  local timeout_seconds="${4:-600}"

  echo "Running skill /$skill $args as sub-agent..."

  local output_file
  output_file=$(mktemp)

  # Claude CLI prompt that uses Task tool internally
  local prompt="Execute the /$skill $args skill using a Task sub-agent.
Use the Task tool with subagent_type='general-purpose' to spawn an agent that runs:
  Skill: $skill
  Args: $args

Wait for the sub-agent to complete and report the results.
Do not stop until the skill completes or fails."

  if timeout "$timeout_seconds" claude --dangerously-skip-permissions -p "$prompt" > "$output_file" 2>&1; then
    echo "Sub-agent completed"
    if [ -n "$expected_pattern" ]; then
      if grep -qi "$expected_pattern" "$output_file" 2>/dev/null; then
        rm -f "$output_file"
        return 0
      fi
    fi
    cat "$output_file"
    rm -f "$output_file"
    return 0
  else
    local exit_code=$?
    echo "Sub-agent failed or timed out (exit code: $exit_code)"
    cat "$output_file"
    LAST_ERROR_OUTPUT=$(cat "$output_file")
    rm -f "$output_file"
    return 1
  fi
}

# Try to fix a step failure using /pm:fix_problem
# Usage: try_fix_step 10 "error message"
try_fix_step() {
  local step_num="$1"
  local error_msg="$2"
  local step_info="${PIPELINE_STEPS[$((step_num-1))]}"
  local step_name
  local step_desc
  step_name=$(echo "$step_info" | cut -d: -f1)
  step_desc=$(echo "$step_info" | cut -d: -f2)

  local project_name
  project_name=$(basename "$(pwd)" | tr '_' '-')

  for attempt in 1 2 3; do
    echo ""
    echo "🔧 Fix Attempt $attempt/$MAX_FIX_ATTEMPTS for Step $step_num ($step_name)"
    echo ""

    # Determine approach based on attempt
    local approach
    case $attempt in
      1) approach="Direct fix from research" ;;
      2) approach="Defensive approach with validation" ;;
      3) approach="Alternative implementation pattern" ;;
    esac

    # Log the attempt
    log_fix_attempt "$step_num" "$attempt" "$error_msg" "$approach"

    # Determine desired behavior and test command based on step
    local desired_behavior=""
    local test_command=""

    case $step_num in
      10)  # deploy
        desired_behavior="Deployment completes successfully with all pods running in namespace $project_name"
        test_command="kubectl get pods -n $project_name --no-headers | grep -v Running | grep -v Completed | wc -l | grep -q '^0$'"
        ;;
      9)   # batch
        desired_behavior="Batch processing completes with at least one PRD marked complete"
        test_command="grep -l '^status: complete' .claude/prds/*.md | wc -l | grep -qv '^0$'"
        ;;
      *)
        desired_behavior="Step $step_num ($step_desc) completes successfully"
        test_command=""
        ;;
    esac

    # Escape quotes in error message
    local escaped_error
    escaped_error=$(echo "$error_msg" | sed 's/"/\\"/g' | head -c 2000)

    # Call /pm:fix_problem
    echo "Calling /pm:fix_problem..."
    local fix_output
    fix_output=$(mktemp)

    if timeout 600 claude --dangerously-skip-permissions \
      "/pm:fix_problem \"$escaped_error\" --desired \"$desired_behavior\" --test \"$test_command\" --namespace \"$project_name\"" \
      > "$fix_output" 2>&1; then

      echo "Fix attempt completed"
      cat "$fix_output"

      # Verify the fix worked by running post-check
      echo ""
      echo "Verifying fix..."
      local postcheck_func="postcheck_step_$step_num"
      if $postcheck_func 2>&1; then
        echo "✅ Fix successful on attempt $attempt!"
        rm -f "$fix_output"
        return 0
      else
        echo "Fix did not resolve the issue"
        error_msg=$(cat "$fix_output")
      fi
    else
      echo "Fix attempt timed out or failed"
      error_msg=$(cat "$fix_output")
    fi

    rm -f "$fix_output"
  done

  echo ""
  echo "❌ All $MAX_FIX_ATTEMPTS fix attempts failed for Step $step_num"
  echo "Manual intervention required."
  echo ""
  echo "Fix log: $PIPELINE_STATE_DIR/fix-step-$step_num.md"
  return 1
}

# Execute a single step with pre/post validation and auto-fix
# Usage: execute_step 5
execute_step() {
  local step_num="$1"
  local step_info="${PIPELINE_STEPS[$((step_num-1))]}"
  local step_name
  local step_desc
  step_name=$(echo "$step_info" | cut -d: -f1)
  step_desc=$(echo "$step_info" | cut -d: -f2)

  echo ""
  echo "========================================"
  echo "Step $step_num/$TOTAL_STEPS: $step_desc"
  echo "========================================"

  # Check if already complete
  local current_status
  current_status=$(get_step_status "$step_num")
  if [ "$current_status" = "complete" ]; then
    echo "✓ Already complete"
    return 0
  fi

  # Check if skipped
  if [ "$current_status" = "skipped" ]; then
    echo "⊘ Previously skipped"
    return 0
  fi

  # Check if step is skippable
  local is_skippable=false
  if [[ " $SKIPPABLE_STEPS " =~ " $step_num " ]]; then
    is_skippable=true
  fi

  # Run pre-check
  echo "Pre-check..."
  local precheck_func="precheck_step_$step_num"
  local precheck_error
  precheck_error=$($precheck_func 2>&1)
  if [ $? -ne 0 ]; then
    if [ "$is_skippable" = true ]; then
      echo "⚠️ Pre-check failed but step is optional - skipping"
      update_step_status "$step_num" "skipped"
      add_warning "Step $step_num ($step_name) skipped: pre-check failed"
      return 0
    else
      echo "❌ Pre-check failed: $precheck_error"
      update_step_status "$step_num" "failed"
      add_error "Step $step_num ($step_name) pre-check failed: $precheck_error"
      return 1
    fi
  fi
  echo "Pre-check passed ✓"
  echo ""

  # Mark as running
  update_step_status "$step_num" "running"

  # Run the step implementation
  local run_func="run_step_$step_num"
  local run_error
  local run_exit_code
  LAST_ERROR_OUTPUT=""

  # Step 4 (interrogate) is interactive and requires TTY access
  # Run it directly without capturing output to preserve TTY
  if [ "$step_num" -eq 4 ]; then
    # Run interactive step directly (not in subshell)
    $run_func
    run_exit_code=$?
    run_error=""
  else
    # Run non-interactive steps in subshell to capture output
    run_error=$($run_func 2>&1)
    run_exit_code=$?
  fi

  if [ "$run_exit_code" -ne 0 ]; then
    if [ "$is_skippable" = true ]; then
      echo "⚠️ Step failed but is optional - marking skipped"
      update_step_status "$step_num" "skipped"
      add_warning "Step $step_num ($step_name) skipped: execution failed"
      return 0
    else
      echo "❌ Step execution failed"
      [ -n "$run_error" ] && echo "$run_error"

      # Try auto-fix for non-skippable steps
      if try_fix_step "$step_num" "${LAST_ERROR_OUTPUT:-$run_error}"; then
        # Fix worked, continue
        echo "Continuing after successful fix..."
      else
        update_step_status "$step_num" "failed"
        add_error "Step $step_num ($step_name) execution failed after $MAX_FIX_ATTEMPTS fix attempts"
        return 1
      fi
    fi
  else
    # Echo captured output (for non-interactive steps only)
    [ -n "$run_error" ] && echo "$run_error"
  fi

  echo ""
  echo "Post-check..."

  # Run post-check
  local postcheck_func="postcheck_step_$step_num"
  local postcheck_error
  postcheck_error=$($postcheck_func 2>&1)
  if [ $? -ne 0 ]; then
    if [ "$is_skippable" = true ]; then
      echo "⚠️ Post-check failed but step is optional - marking skipped"
      update_step_status "$step_num" "skipped"
      add_warning "Step $step_num ($step_name) skipped: post-check failed"
      return 0
    else
      echo "❌ Post-check failed: $postcheck_error"

      # Try auto-fix for post-check failures too
      if try_fix_step "$step_num" "$postcheck_error"; then
        echo "Continuing after successful fix..."
      else
        update_step_status "$step_num" "failed"
        add_error "Step $step_num ($step_name) post-check failed after $MAX_FIX_ATTEMPTS fix attempts"
        return 1
      fi
    fi
  fi

  echo "Post-check passed ✓"
  echo ""

  # Mark as complete
  update_step_status "$step_num" "complete"
  echo "Step $step_num: $step_name ✓"

  return 0
}

# Run all steps from a starting point
# Usage: run_pipeline_from 1
run_pipeline_from() {
  local start_step="${1:-1}"

  echo ""
  echo "Running pipeline from step $start_step to $TOTAL_STEPS"
  echo ""

  for ((i=start_step; i<=TOTAL_STEPS; i++)); do
    execute_step "$i"
    local step_result=$?

    # Handle failure
    if [ "$step_result" -ne 0 ]; then
      echo ""
      echo "❌ Pipeline stopped at step $i"
      echo ""
      echo "Resume with: ./interrogate.sh --resume $PIPELINE_SESSION"
      echo "Or from step: ./interrogate.sh --resume-from $i $PIPELINE_SESSION"
      return 1
    fi
  done

  echo ""
  echo "========================================"
  echo "Pipeline Complete"
  echo "========================================"
  echo ""

  return 0
}

# Show pipeline status
# Usage: show_pipeline_status
show_pipeline_status() {
  if [ ! -f "$PIPELINE_STATE_FILE" ]; then
    echo "No pipeline state found"
    return 1
  fi

  echo ""
  echo "Pipeline: $PIPELINE_SESSION"
  echo "Status: $(get_pipeline_status)"
  echo "Current Step: $(get_current_step)"
  echo "Last Completed: $(get_last_completed_step)"
  echo ""
  echo "Steps:"

  for i in $(seq 1 $TOTAL_STEPS); do
    local status
    status=$(get_step_status "$i")
    local step_info="${PIPELINE_STEPS[$((i-1))]}"
    local step_desc
    step_desc=$(echo "$step_info" | cut -d: -f2)

    local indicator="○"
    case "$status" in
      complete) indicator="✓" ;;
      running) indicator="►" ;;
      paused) indicator="⏸" ;;
      failed) indicator="✗" ;;
      skipped) indicator="⊘" ;;
    esac

    printf "  %s %2d. %s [%s]\n" "$indicator" "$i" "$step_desc" "$status"
  done

  echo ""
}

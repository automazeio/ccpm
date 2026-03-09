#!/usr/bin/env bash
# feedback-pipeline.sh - Orchestrate test-driven issue resolution
#
# Pipeline flow:
#   test-journey -> generate-feedback -> analyze-feedback -> research -> fix
#
# Usage:
#   ./feedback-pipeline.sh <session-name>           # Run full pipeline
#   ./feedback-pipeline.sh <session-name> --resume  # Resume from saved state
#   ./feedback-pipeline.sh <session-name> --status  # Show pipeline status

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Pipeline state (globals)
SESSION=""
TEST_RUN_ID=""
FEEDBACK_STATE_DIR=""
FEEDBACK_STATE_FILE=""

# Source pipeline library for state management
if [[ -f "${SCRIPT_DIR}/pipeline-lib.sh" ]]; then
  # shellcheck source=pipeline-lib.sh
  source "${SCRIPT_DIR}/pipeline-lib.sh"
fi

# Show usage information.
# Outputs:
#   Writes usage to stdout
usage() {
  cat << 'EOF'
Feedback Pipeline - Test-Driven Issue Resolution

Usage:
  ./feedback-pipeline.sh <session-name>           Run full pipeline
  ./feedback-pipeline.sh <session-name> --resume  Resume from saved state
  ./feedback-pipeline.sh <session-name> --status  Show pipeline status

Pipeline Steps:
  1. Ensure feedback tables exist
  2. Run journey tests for all personas
  3. Generate synthetic feedback
  4. Analyze and prioritize issues
  5. Deep research on each issue
  6. Fix each issue (with retry/escalation)
  7. Convert escalated issues to PRDs

Database Status Transitions:
  analyze-feedback creates issue -> status='open'
  /dr completes research        -> status='triaged'
  fix-problem succeeds          -> status='resolved'
  fix-problem fails (3x)        -> status='escalated'
  issues-to-prd creates PRD     -> status='prd_created'

Output:
  Pipeline state: .claude/pipeline/<session>/feedback-state.yaml
  Fix logs:       .claude/pipeline/<session>/fix-issue-*.md
EOF
  exit 1
}

# Log info message with timestamp.
# Arguments:
#   $1 - message to log
log() {
  echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

# Log success message with timestamp.
# Arguments:
#   $1 - message to log
log_success() {
  echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"
}

# Log error message with timestamp.
# Arguments:
#   $1 - message to log
log_error() {
  echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"
}

# Log warning message with timestamp.
# Arguments:
#   $1 - message to log
log_warn() {
  echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"
}

# App process tracking
FRONTEND_PID=""
BACKEND_PID=""
FRONTEND_PORT=""
APP_STARTED=false

# Cleanup function - kill app processes on exit.
cleanup() {
  if [[ "${APP_STARTED}" == "true" ]]; then
    log "Cleaning up application processes..."
    stop_app
  fi
}

# Set trap for cleanup on script exit
trap cleanup EXIT INT TERM

# Start the application (frontend and backend).
# Globals:
#   FRONTEND_PID - set to frontend process ID
#   BACKEND_PID - set to backend process ID
#   APP_STARTED - set to true if app started successfully
start_app() {
  log "Starting application for E2E tests..."

  # Common frontend ports: Vite (5173-5175), CRA/Next (3000-3002)
  local -a FRONTEND_PORTS=(5173 5174 5175 3000 3001 3002)

  # Check if already running on any common port
  local port
  for port in "${FRONTEND_PORTS[@]}"; do
    if curl -s --max-time 2 "http://localhost:${port}" > /dev/null 2>&1; then
      log "Frontend already running on port ${port}"
      FRONTEND_PORT="${port}"
      APP_STARTED=false  # Don't kill it on exit since we didn't start it
      return 0
    fi
  done

  # Start backend
  if [[ -d "${PROJECT_ROOT}/backend" ]]; then
    log "Starting backend..."
    cd "${PROJECT_ROOT}/backend"

    # Activate venv if exists
    if [[ -f "venv/bin/activate" ]]; then
      source venv/bin/activate
    elif [[ -f ".venv/bin/activate" ]]; then
      source .venv/bin/activate
    fi

    # Start uvicorn in background
    uvicorn app.main:app --host 0.0.0.0 --port 8000 > "${FEEDBACK_STATE_DIR}/backend.log" 2>&1 &
    BACKEND_PID=$!
    cd "${PROJECT_ROOT}"
    log "Backend started (PID: ${BACKEND_PID})"
  fi

  # Start frontend
  if [[ -d "${PROJECT_ROOT}/frontend" ]]; then
    log "Starting frontend..."
    cd "${PROJECT_ROOT}/frontend"
    npm run dev > "${FEEDBACK_STATE_DIR}/frontend.log" 2>&1 &
    FRONTEND_PID=$!
    cd "${PROJECT_ROOT}"
    log "Frontend started (PID: ${FRONTEND_PID})"
  fi

  APP_STARTED=true

  # Wait for services to be ready - check log for actual port or try common ports
  log "Waiting for frontend to be ready..."
  local retries=30
  local detected_port=""
  while ((retries > 0)); do
    # Try to detect port from Vite log output
    if [[ -f "${FEEDBACK_STATE_DIR}/frontend.log" ]]; then
      detected_port=$(grep -oE 'http://localhost:[0-9]+' "${FEEDBACK_STATE_DIR}/frontend.log" | head -1 | grep -oE '[0-9]+$' || echo "")
    fi

    # Check detected port first, then fall back to common ports
    if [[ -n "${detected_port}" ]]; then
      if curl -s --max-time 2 "http://localhost:${detected_port}" > /dev/null 2>&1; then
        FRONTEND_PORT="${detected_port}"
        log_success "Frontend is ready on port ${FRONTEND_PORT}"
        break
      fi
    else
      # Check common ports
      for port in "${FRONTEND_PORTS[@]}"; do
        if curl -s --max-time 2 "http://localhost:${port}" > /dev/null 2>&1; then
          FRONTEND_PORT="${port}"
          log_success "Frontend is ready on port ${FRONTEND_PORT}"
          break 2
        fi
      done
    fi

    ((--retries))
    sleep 1
  done

  if ((retries == 0)); then
    log_error "Frontend failed to start within 30 seconds"
    log "Check logs: ${FEEDBACK_STATE_DIR}/frontend.log"
    return 1
  fi

  # Check backend
  retries=10
  while ((retries > 0)); do
    if curl -s --max-time 2 http://localhost:8000/health > /dev/null 2>&1 || \
       curl -s --max-time 2 http://localhost:8000/api > /dev/null 2>&1 || \
       curl -s --max-time 2 http://localhost:8000 > /dev/null 2>&1; then
      log_success "Backend is ready on port 8000"
      break
    fi
    ((--retries))
    sleep 1
  done

  return 0
}

# Stop the application processes.
# Globals:
#   FRONTEND_PID - frontend process to kill
#   BACKEND_PID - backend process to kill
stop_app() {
  if [[ -n "${FRONTEND_PID}" ]]; then
    log "Stopping frontend (PID: ${FRONTEND_PID})..."
    kill "${FRONTEND_PID}" 2>/dev/null || true
    wait "${FRONTEND_PID}" 2>/dev/null || true
    FRONTEND_PID=""
  fi

  if [[ -n "${BACKEND_PID}" ]]; then
    log "Stopping backend (PID: ${BACKEND_PID})..."
    kill "${BACKEND_PID}" 2>/dev/null || true
    wait "${BACKEND_PID}" 2>/dev/null || true
    BACKEND_PID=""
  fi

  APP_STARTED=false
  log_success "Application stopped"
}

# Initialize feedback pipeline state.
# Globals:
#   FEEDBACK_STATE_DIR - set to state directory
#   FEEDBACK_STATE_FILE - set to state file path
#   TEST_RUN_ID - loaded from existing state if present
# Arguments:
#   $1 - session name
init_feedback_state() {
  local -r session="$1"

  FEEDBACK_STATE_DIR="${PROJECT_ROOT}/.claude/pipeline/${session}"
  FEEDBACK_STATE_FILE="${FEEDBACK_STATE_DIR}/feedback-state.yaml"

  mkdir -p "${FEEDBACK_STATE_DIR}"

  if [[ ! -f "${FEEDBACK_STATE_FILE}" ]]; then
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "${FEEDBACK_STATE_FILE}" << EOF
---
session: ${session}
pipeline: feedback
status: pending
test_run_id: ""
current_step: 0
started: ${now}
updated: ${now}
steps:
  1: {name: ensure_tables, status: pending}
  2: {name: test_journeys, status: pending}
  3: {name: generate_feedback, status: pending}
  4: {name: analyze_feedback, status: pending}
  5: {name: research_issues, status: pending}
  6: {name: fix_issues, status: pending}
  7: {name: escalate_to_prds, status: pending}
stats:
  journeys_tested: 0
  personas_tested: 0
  issues_found: 0
  issues_triaged: 0
  issues_resolved: 0
  issues_escalated: 0
  prds_created: 0
---
EOF
    log "Pipeline state initialized: ${FEEDBACK_STATE_FILE}"
  else
    log "Pipeline state loaded: ${FEEDBACK_STATE_FILE}"
    # Load existing test_run_id
    TEST_RUN_ID=$(grep "^test_run_id:" "${FEEDBACK_STATE_FILE}" | cut -d'"' -f2)
  fi
}

# Update feedback state key-value pair.
# Arguments:
#   $1 - key to update
#   $2 - value to set
update_feedback_state() {
  local -r key="$1"
  local -r value="$2"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  sed -i "s/^${key}:.*/${key}: ${value}/" "${FEEDBACK_STATE_FILE}"
  sed -i "s/^updated:.*/updated: ${now}/" "${FEEDBACK_STATE_FILE}"
}

# Update step status in state file.
# Arguments:
#   $1 - step number (1-6)
#   $2 - status (pending, running, complete)
update_step_status() {
  local -r step_num="$1"
  local -r status="$2"
  local step_name

  case "${step_num}" in
    1) step_name="ensure_tables" ;;
    2) step_name="test_journeys" ;;
    3) step_name="generate_feedback" ;;
    4) step_name="analyze_feedback" ;;
    5) step_name="research_issues" ;;
    6) step_name="fix_issues" ;;
    7) step_name="escalate_to_prds" ;;
  esac

  sed -i "s/^  ${step_num}: {name: ${step_name}, status: [a-z]*}/  ${step_num}: {name: ${step_name}, status: ${status}}/" "${FEEDBACK_STATE_FILE}"
  update_feedback_state "current_step" "${step_num}"

  if [[ "${status}" == "running" ]]; then
    update_feedback_state "status" "in_progress"
  elif [[ "${status}" == "complete" ]] && ((step_num == 7)); then
    update_feedback_state "status" "complete"
  fi
}

# Update stats in state file.
# Arguments:
#   $1 - stat name
#   $2 - value
update_stat() {
  local -r stat="$1"
  local -r value="$2"
  sed -i "s/^  ${stat}:.*$/  ${stat}: ${value}/" "${FEEDBACK_STATE_FILE}"
}

# Get database connection string from environment.
# Outputs:
#   Writes connection string to stdout
get_db_conn() {
  if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/.env"
    set +a
  fi

  local -r host="${POSTGRES_HOST:-localhost}"
  local -r port="${POSTGRES_PORT:-5432}"
  local -r user="${POSTGRES_USER:-postgres}"
  local -r pass="${POSTGRES_PASSWORD:-}"
  local db
  db="${POSTGRES_DB:-$(basename "${PROJECT_ROOT}")}"

  echo "postgresql://${user}:${pass}@${host}:${port}/${db}"
}

# Run database query.
# Arguments:
#   $1 - SQL query
# Outputs:
#   Writes query result to stdout
db_query() {
  local -r query="$1"
  local conn
  conn=$(get_db_conn)
  psql "${conn}" -t -A -c "${query}" 2>/dev/null || echo ""
}

# Sync personas from JSON file to database.
# Arguments:
#   $1 - path to personas JSON file
sync_personas_to_db() {
  local -r json_file="$1"

  if [[ ! -f "${json_file}" ]]; then
    log_error "Personas file not found: ${json_file}"
    return 1
  fi

  local count=0
  local persona_ids
  persona_ids=$(jq -r '.personas[].id' "${json_file}" 2>/dev/null || echo "")

  if [[ -z "${persona_ids}" ]]; then
    log_error "No personas found in JSON file"
    return 1
  fi

  # Process each persona
  local idx=0
  while IFS= read -r persona_id; do
    [[ -z "${persona_id}" ]] && continue

    # Extract persona data using jq
    local name role demographics behavioral journeys test_data feedback metadata
    name=$(jq -r ".personas[${idx}].name // \"\"" "${json_file}" | sed "s/'/''/g")
    role=$(jq -r ".personas[${idx}].role // \"\"" "${json_file}" | sed "s/'/''/g")
    demographics=$(jq -c ".personas[${idx}].demographics // {}" "${json_file}" | sed "s/'/''/g")
    behavioral=$(jq -c ".personas[${idx}].behavioral // {}" "${json_file}" | sed "s/'/''/g")
    journeys=$(jq -c ".personas[${idx}].journeys // {}" "${json_file}" | sed "s/'/''/g")
    test_data=$(jq -c ".personas[${idx}].testData // {}" "${json_file}" | sed "s/'/''/g")
    feedback=$(jq -c ".personas[${idx}].feedback // {}" "${json_file}" | sed "s/'/''/g")
    metadata=$(jq -c ".personas[${idx}].metadata // {}" "${json_file}" | sed "s/'/''/g")

    # Upsert into database (suppress output)
    db_query "INSERT INTO persona (session_name, persona_id, name, role, demographics, behavioral, journeys, test_data, feedback_preferences, metadata)
              VALUES ('${SESSION}', '${persona_id}', '${name}', '${role}', '${demographics}'::jsonb, '${behavioral}'::jsonb, '${journeys}'::jsonb, '${test_data}'::jsonb, '${feedback}'::jsonb, '${metadata}'::jsonb)
              ON CONFLICT (session_name, persona_id) DO UPDATE SET
                name = EXCLUDED.name,
                role = EXCLUDED.role,
                demographics = EXCLUDED.demographics,
                behavioral = EXCLUDED.behavioral,
                journeys = EXCLUDED.journeys,
                test_data = EXCLUDED.test_data,
                feedback_preferences = EXCLUDED.feedback_preferences,
                metadata = EXCLUDED.metadata" > /dev/null

    ((++count))
    ((++idx))
  done <<< "${persona_ids}"

  log_success "Synced ${count} personas to database"
}

# Step 1: Ensure feedback tables exist.
step_ensure_tables() {
  log "Step 1: Ensuring feedback tables exist"
  update_step_status 1 "running"

  if [[ -f "${SCRIPT_DIR}/create-feedback-schema.sh" ]]; then
    "${SCRIPT_DIR}/create-feedback-schema.sh"
  else
    log_error "create-feedback-schema.sh not found"
    return 1
  fi

  update_step_status 1 "complete"
  log_success "Feedback tables ready"
}

# Step 2: Run all journey tests.
step_test_journeys() {
  log "Step 2: Testing user journeys"
  update_step_status 2 "running"

  # Start the application if not already running
  if ! start_app; then
    log_error "Failed to start application - skipping journey tests"
    update_step_status 2 "complete"
    return 0
  fi

  # Generate test run ID
  TEST_RUN_ID="run-$(date +%Y%m%d-%H%M%S)"
  update_feedback_state "test_run_id" "\"${TEST_RUN_ID}\""

  # Get journeys from database (journey_id is the human-readable ID like "J-001")
  local journeys
  journeys=$(db_query "SELECT journey_id FROM journey WHERE session_name='${SESSION}'")

  if [[ -z "${journeys}" ]]; then
    log_warn "No journeys found in database for session: ${SESSION}"
    # Try to get from file
    local -r journeys_file="${PROJECT_ROOT}/.claude/scopes/${SESSION}/02_user_journeys.md"
    if [[ -f "${journeys_file}" ]]; then
      log "Using journeys from file: ${journeys_file}"
    fi
  fi

  # Get personas from database
  local personas
  personas=$(db_query "SELECT persona_id FROM persona WHERE session_name='${SESSION}'")

  if [[ -z "${personas}" ]]; then
    log_warn "No personas found in database for session: ${SESSION}"

    # Check if JSON file exists and sync to database
    local -r personas_file="${PROJECT_ROOT}/.claude/testing/personas/${SESSION}-personas.json"
    if [[ -f "${personas_file}" ]]; then
      log "Found personas JSON file, syncing to database..."
      sync_personas_to_db "${personas_file}"
      # Re-query after sync
      personas=$(db_query "SELECT persona_id FROM persona WHERE session_name='${SESSION}'")
    fi

    # If still empty, generate personas automatically
    if [[ -z "${personas}" ]]; then
      log "Generating personas automatically..."
      claude --dangerously-skip-permissions --print "/pm:generate-personas ${SESSION} --count 5" || true

      # Sync newly generated JSON to database
      if [[ -f "${personas_file}" ]]; then
        sync_personas_to_db "${personas_file}"
      fi

      # Re-query after generation
      personas=$(db_query "SELECT persona_id FROM persona WHERE session_name='${SESSION}'")

      if [[ -z "${personas}" ]]; then
        log_error "Failed to generate personas"
        update_step_status 2 "complete"
        log_warn "Step 2 skipped - persona generation failed"
        return 0
      fi
    fi
  fi

  local journey_count=0
  local persona_count=0

  # Run test-journey for each combination using direct Playwright (not MCP)
  local journey_id
  for journey_id in ${journeys}; do
    [[ -z "${journey_id}" ]] && continue
    ((++journey_count))

    # Fetch journey data from database (with steps from journey_steps_detailed)
    local journey_data
    journey_data=$(db_query "SELECT json_build_object(
      'journey_id', j.journey_id,
      'name', j.name,
      'goal', j.goal,
      'steps', COALESCE((
        SELECT json_agg(json_build_object(
          'step_number', s.step_number,
          'step_name', s.step_name,
          'user_action', s.user_action,
          'ui_page_route', s.ui_page_route,
          'ui_component_type', s.ui_component_type,
          'ui_component_name', s.ui_component_name
        ) ORDER BY s.step_number)
        FROM journey_steps_detailed s WHERE s.journey_id = j.id
      ), '[]'::json)
    ) FROM journey j WHERE j.session_name='${SESSION}' AND j.journey_id='${journey_id}'") || true

    local persona_id
    for persona_id in ${personas}; do
      [[ -z "${persona_id}" ]] && continue
      ((++persona_count))

      # Fetch persona data from database
      local persona_data
      persona_data=$(db_query "SELECT json_build_object(
        'id', persona_id,
        'name', name,
        'role', role,
        'demographics', COALESCE(demographics, '{}'::jsonb),
        'behavioral', COALESCE(behavioral, '{}'::jsonb),
        'journeys', COALESCE(journeys, '[]'::jsonb),
        'testData', COALESCE(test_data, '{}'::jsonb)
      ) FROM persona WHERE session_name='${SESSION}' AND persona_id='${persona_id}'") || true

      log "Testing journey ${journey_id} with persona ${persona_id}"

      # Write journey/persona data to temp files to avoid shell quoting issues
      local journey_file persona_file test_stderr
      journey_file=$(mktemp)
      persona_file=$(mktemp)
      test_stderr=$(mktemp)

      # Write JSON to temp files - use explicit check to avoid bash brace expansion issues
      if [[ -n "${journey_data}" ]]; then
        printf '%s' "${journey_data}" > "${journey_file}"
      else
        echo '{}' > "${journey_file}"
      fi
      if [[ -n "${persona_data}" ]]; then
        printf '%s' "${persona_data}" > "${persona_file}"
      else
        echo '{}' > "${persona_file}"
      fi

      # Run direct Playwright test
      local test_output test_exit_code
      test_output=$(node "${SCRIPT_DIR}/playwright-journey-test.js" \
        --session "${SESSION}" \
        --journey "${journey_id}" \
        --persona "${persona_id}" \
        --journey-file "${journey_file}" \
        --persona-file "${persona_file}" \
        --base-url "http://localhost:${FRONTEND_PORT:-5173}" \
        --test-run-id "${TEST_RUN_ID}" 2>"${test_stderr}") || test_exit_code=$?

      # Clean up temp files
      rm -f "${journey_file}" "${persona_file}"

      # Log errors/warnings from stderr (skip debug lines)
      if [[ -s "${test_stderr}" ]]; then
        if grep -qi "error\|warning\|fail" "${test_stderr}" 2>/dev/null; then
          log_warn "Playwright issues:"
          grep -i "error\|warning\|fail" "${test_stderr}" | head -5 | while IFS= read -r line; do log "  $line"; done
        fi
      fi
      rm -f "${test_stderr}"

      # Parse and insert results to database
      if [[ -n "${test_output}" ]]; then
        local overall_status steps_passed steps_failed
        overall_status=$(echo "${test_output}" | jq -r '.overall_status // "fail"')
        steps_passed=$(echo "${test_output}" | jq -r '.steps_passed // 0')
        steps_failed=$(echo "${test_output}" | jq -r '.steps_failed // 0')
        local step_results issues_found screenshots_count
        step_results=$(echo "${test_output}" | jq -c '.step_results // []')
        issues_found=$(echo "${test_output}" | jq -c '.issues_found // []')
        screenshots_count=$(echo "${test_output}" | jq -r '.screenshots_count // 0')

        # Insert into test_results table
        db_query "INSERT INTO test_results (session_name, test_run_id, persona_id, base_url, overall_status, steps_passed, steps_failed, step_results, issues_found, screenshots_count)
                  VALUES ('${SESSION}', '${TEST_RUN_ID}', '${persona_id}', 'http://localhost:${FRONTEND_PORT:-5173}', '${overall_status}', ${steps_passed}, ${steps_failed}, '${step_results}'::jsonb, '${issues_found}'::jsonb, ${screenshots_count})" > /dev/null

        if [[ "${overall_status}" == "pass" ]]; then
          log_success "Journey ${journey_id} with ${persona_id}: PASSED (${steps_passed} steps)"
        else
          log_warn "Journey ${journey_id} with ${persona_id}: ${overall_status^^} (${steps_passed} passed, ${steps_failed} failed)"
        fi
      else
        log_error "Journey ${journey_id} with ${persona_id}: No output from test"
      fi
    done
  done

  update_stat "journeys_tested" "${journey_count}"
  update_stat "personas_tested" "${persona_count}"
  update_step_status 2 "complete"
  log_success "Tested ${journey_count} journeys with ${persona_count} persona runs"
}

# Step 3: Generate synthetic feedback.
step_generate_feedback() {
  log "Step 3: Generating feedback"
  log "  This step invokes Claude to generate synthetic user feedback..."
  log "  Command: /pm:generate-feedback ${SESSION} --run ${TEST_RUN_ID}"
  update_step_status 3 "running"

  local start_time
  start_time=$(date +%s)

  claude --dangerously-skip-permissions --print "/pm:generate-feedback ${SESSION} --run ${TEST_RUN_ID}"

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  log "  Feedback generation completed in ${elapsed}s"

  update_step_status 3 "complete"
  log_success "Feedback generated"
}

# Step 4: Analyze and prioritize issues.
step_analyze_feedback() {
  log "Step 4: Analyzing feedback"
  log "  This step invokes Claude to analyze test results and create issues..."
  log "  Command: /pm:analyze-feedback ${SESSION} --run ${TEST_RUN_ID}"
  update_step_status 4 "running"

  local start_time
  start_time=$(date +%s)

  claude --dangerously-skip-permissions --print "/pm:analyze-feedback ${SESSION} --run ${TEST_RUN_ID}"

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  log "  Analysis completed in ${elapsed}s"

  # Sync generated issues from JSON to database
  log "Syncing issues to database..."
  if [[ -f "${SCRIPT_DIR}/sync-issues-to-db.sh" ]]; then
    "${SCRIPT_DIR}/sync-issues-to-db.sh" "${SESSION}" "${TEST_RUN_ID}" || {
      log_warn "Issue sync had warnings (non-fatal)"
    }
  else
    log_warn "sync-issues-to-db.sh not found - issues not persisted to database"
  fi

  # Count issues created
  local issue_count
  issue_count=$(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND test_run_id='${TEST_RUN_ID}'")
  update_stat "issues_found" "${issue_count:-0}"

  update_step_status 4 "complete"
  log_success "Analysis complete: ${issue_count:-0} issues found"
}

# Step 5: Deep research on each issue.
step_research_issues() {
  log "Step 5: Researching fixes"
  update_step_status 5 "running"

  # Process ALL open issues for this session (not just current test run)
  # Use DISTINCT ON to avoid processing duplicate issue_ids from different test runs
  # Replace newlines in description with spaces to avoid breaking the while read loop
  local issues
  issues=$(db_query "
    SELECT DISTINCT ON (issue_id) issue_id, title,
           REPLACE(REPLACE(COALESCE(description, ''), E'\\n', ' '), E'\\r', ' ') as description,
           category, severity
    FROM issues
    WHERE session_name='${SESSION}'
      AND status='open'
    ORDER BY issue_id,
      CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
      END,
      rice_score DESC NULLS LAST
  ")

  local triaged_count=0
  local issue_id title description category severity

  # Debug: show how many issues we'll process
  local issue_count
  issue_count=$(echo "${issues}" | grep -c . || echo 0)
  log "Found ${issue_count} open issues to research"

  while IFS='|' read -r issue_id title description category severity; do
    [[ -z "${issue_id}" ]] && continue
    issue_id=$(echo "${issue_id}" | xargs)
    title=$(echo "${title}" | xargs)

    log "Researching (${triaged_count}/${issue_count}): ${issue_id} - ${title}"

    # Build research prompt
    local prompt="How to fix this ${category} issue (${severity} severity):
Title: ${title}
Description: ${description}

Research: root causes, best practices, specific code fixes for this codebase"

    # Run deep research (redirect stdin to prevent consuming while loop input)
    local research_output
    research_output=$(claude --dangerously-skip-permissions --print "/dr ${prompt}" </dev/null 2>&1 || echo "Research incomplete")

    # Escape for SQL
    local escaped_research
    escaped_research=$(echo "${research_output}" | sed "s/'/''/g" | head -c 50000)

    # Store research in database and update status
    db_query "UPDATE issues
             SET research_context = '${escaped_research}',
                 status = 'triaged'
             WHERE session_name='${SESSION}'
               AND issue_id='${issue_id}'
               AND status='open'"

    ((++triaged_count))
    log_success "${issue_id} triaged"
  done <<< "${issues}"

  update_stat "issues_triaged" "${triaged_count}"
  update_step_status 5 "complete"
  log_success "Researched ${triaged_count} issues"
}

# Step 6: Fix each issue.
step_fix_issues() {
  log "Step 6: Fixing issues"
  update_step_status 6 "running"

  # Process ALL triaged issues for this session (not just current test run)
  # Use DISTINCT ON to avoid processing duplicate issue_ids from different test runs
  # Replace newlines with spaces to avoid breaking the while read loop
  local issues
  issues=$(db_query "
    SELECT DISTINCT ON (issue_id) issue_id, title,
           REPLACE(REPLACE(COALESCE(description, ''), E'\\n', ' '), E'\\r', ' ') as description,
           category, severity,
           REPLACE(REPLACE(COALESCE(research_context, ''), E'\\n', ' '), E'\\r', ' ') as research_context
    FROM issues
    WHERE session_name='${SESSION}'
      AND status='triaged'
    ORDER BY issue_id,
      CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
      END
  ")

  local resolved_count=0
  local escalated_count=0
  local -r max_attempts=3
  local issue_id title description category severity research

  while IFS='|' read -r issue_id title description category severity research; do
    [[ -z "${issue_id}" ]] && continue
    issue_id=$(echo "${issue_id}" | xargs)
    title=$(echo "${title}" | xargs)

    log "Fixing: ${issue_id} - ${title}"

    # Create fix log
    local -r fix_log="${FEEDBACK_STATE_DIR}/fix-issue-${issue_id}.md"
    cat > "${fix_log}" << EOF
# Fix Attempts for Issue ${issue_id}

## Issue Details
- **Title**: ${title}
- **Category**: ${category}
- **Severity**: ${severity}
- **Description**: ${description}

## Research Findings
${research}

## Fix Attempts

EOF

    local fixed=false
    local attempt
    for attempt in $(seq 1 "${max_attempts}"); do
      log "  Attempt ${attempt}/${max_attempts}"

      # Build error context for fix-problem
      local error_context="Issue: ${title}
Category: ${category}
Severity: ${severity}
Description: ${description}

Research findings:
${research}"

      # Escape quotes
      local escaped_context
      escaped_context=$(echo "${error_context}" | sed 's/"/\\"/g' | head -c 5000)

      echo "### Attempt ${attempt} - $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${fix_log}"

      # Call fix-problem (redirect stdin to prevent consuming while loop input)
      if claude --dangerously-skip-permissions --print \
        "/pm:fix-problem \"${escaped_context}\" --desired \"${title} is resolved\"" </dev/null >> "${fix_log}" 2>&1; then

        # Update status to resolved
        db_query "UPDATE issues
                 SET status = 'resolved',
                     fix_attempts = ${attempt},
                     resolved_at = NOW()
                 WHERE session_name='${SESSION}'
                   AND issue_id='${issue_id}'"

        ((++resolved_count))
        log_success "${issue_id} resolved on attempt ${attempt}"
        fixed=true
        break
      else
        echo "**Result**: Failed" >> "${fix_log}"
        echo "" >> "${fix_log}"

        # Increment fix_attempts
        db_query "UPDATE issues
                 SET fix_attempts = ${attempt}
                 WHERE session_name='${SESSION}'
                   AND issue_id='${issue_id}'"
      fi
    done

    if [[ "${fixed}" == "false" ]]; then
      # Escalate after max attempts
      db_query "UPDATE issues
               SET status = 'escalated',
                   fix_attempts = ${max_attempts}
               WHERE session_name='${SESSION}'
                 AND issue_id='${issue_id}'"

      ((++escalated_count))
      log_error "${issue_id} escalated (fix failed after ${max_attempts} attempts)"
      echo "**Final Status**: ESCALATED - requires manual intervention" >> "${fix_log}"
    fi
  done <<< "${issues}"

  update_stat "issues_resolved" "${resolved_count}"
  update_stat "issues_escalated" "${escalated_count}"
  update_step_status 6 "complete"

  log_success "Fixed ${resolved_count} issues, escalated ${escalated_count}"
}

# Step 7: Convert escalated issues to PRDs for manual handling.
step_escalate_to_prds() {
  log "Step 7: Converting escalated issues to PRDs"
  update_step_status 7 "running"

  # Count escalated issues (all for session, not just current test run)
  local escalated_count
  escalated_count=$(db_query "SELECT COUNT(*) FROM issues
                              WHERE session_name='${SESSION}'
                              AND status='escalated'")

  if ((escalated_count == 0)); then
    log "No escalated issues - skipping PRD generation"
    update_step_status 7 "complete"
    return 0
  fi

  log "${escalated_count} issues escalated - converting to PRDs for manual attention"

  # Mark escalated issues as triaged temporarily for PRD generation
  db_query "UPDATE issues SET status='triaged'
            WHERE session_name='${SESSION}'
            AND status='escalated'"

  # Call issues-to-prd.sh to generate PRDs
  if [[ -f "${SCRIPT_DIR}/issues-to-prd.sh" ]]; then
    if "${SCRIPT_DIR}/issues-to-prd.sh" "${SESSION}" --max "${escalated_count}"; then
      local prds_created
      prds_created=$(db_query "SELECT COUNT(*) FROM issues
                               WHERE session_name='${SESSION}'
                               AND status='prd_created'")
      update_stat "prds_created" "${prds_created:-0}"
      log_success "Created PRDs for ${prds_created:-0} escalated issues"
    else
      log_error "PRD generation failed"
      # Revert status back to escalated
      db_query "UPDATE issues SET status='escalated'
                WHERE session_name='${SESSION}'
                AND status='triaged'"
    fi
  else
    log_error "issues-to-prd.sh not found at ${SCRIPT_DIR}/issues-to-prd.sh"
    # Revert status back to escalated
    db_query "UPDATE issues SET status='escalated'
              WHERE session_name='${SESSION}'
              AND status='triaged'"
  fi

  update_step_status 7 "complete"
}

# Show pipeline status.
show_status() {
  if [[ ! -f "${FEEDBACK_STATE_FILE}" ]]; then
    echo "No feedback pipeline state found for: ${SESSION}"
    return 1
  fi

  echo ""
  echo "=== Feedback Pipeline: ${SESSION} ==="
  echo ""
  cat "${FEEDBACK_STATE_FILE}"
  echo ""

  # Show issue counts from database
  echo "Database Status:"
  echo "  Open:        $(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND status='open'")"
  echo "  Triaged:     $(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND status='triaged'")"
  echo "  Resolved:    $(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND status='resolved'")"
  echo "  Escalated:   $(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND status='escalated'")"
  echo "  PRD Created: $(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND status='prd_created'")"
  echo ""
}

# Run pipeline from specified step.
# Arguments:
#   $1 - starting step (default: 1)
run_pipeline() {
  local -r start_step="${1:-1}"

  echo ""
  echo "========================================"
  echo "Feedback Pipeline: ${SESSION}"
  echo "========================================"
  echo ""

  local step
  for step in $(seq "${start_step}" 7); do
    case "${step}" in
      1) step_ensure_tables ;;
      2) step_test_journeys ;;
      3) step_generate_feedback ;;
      4) step_analyze_feedback ;;
      5) step_research_issues ;;
      6) step_fix_issues ;;
      7) step_escalate_to_prds ;;
    esac

    echo ""
  done

  # Final summary
  local resolved escalated prds_created
  resolved=$(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND test_run_id='${TEST_RUN_ID}' AND status='resolved'")
  escalated=$(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND test_run_id='${TEST_RUN_ID}' AND status='escalated'")
  prds_created=$(db_query "SELECT COUNT(*) FROM issues WHERE session_name='${SESSION}' AND test_run_id='${TEST_RUN_ID}' AND status='prd_created'")

  echo ""
  echo "========================================"
  echo "Pipeline Complete"
  echo "========================================"
  echo ""
  echo "  Resolved:     ${resolved:-0} issues"
  echo "  Escalated:    ${escalated:-0} issues"
  echo "  PRDs Created: ${prds_created:-0}"
  echo ""
  echo "State: ${FEEDBACK_STATE_FILE}"
  if ((prds_created > 0)); then
    echo "PRDs:  .claude/prds/"
    echo ""
    echo "Next steps for PRDs:"
    echo "  1. Review PRDs in .claude/prds/"
    echo "  2. /pm:prd-parse <name> to create epics"
    echo "  3. /pm:epic-decompose <name> to create tasks"
  fi
  echo ""
}

# Main entry point.
# Arguments:
#   $@ - command line arguments
main() {
  (($# < 1)) && usage

  SESSION="$1"
  shift

  # Initialize state
  init_feedback_state "${SESSION}"

  # Handle options
  case "${1:-}" in
    --resume)
      # Get current step and check its status
      local current step_status
      current=$(grep "^current_step:" "${FEEDBACK_STATE_FILE}" | cut -d: -f2 | tr -d ' ')

      if [[ -z "${current}" ]] || ((current == 0)); then
        run_pipeline 1
      elif ((current >= 7)); then
        # Check if step 7 actually completed
        step_status=$(grep "^  7: {" "${FEEDBACK_STATE_FILE}" | grep -oP 'status: \K[a-z]+' || echo "pending")
        if [[ "${step_status}" == "complete" ]]; then
          echo "Pipeline already complete for: ${SESSION}"
          show_status
        else
          log_warn "Resuming interrupted step 7"
          run_pipeline 7
        fi
      else
        # Check status of current step
        step_status=$(grep "^  ${current}: {" "${FEEDBACK_STATE_FILE}" | grep -oP 'status: \K[a-z]+' || echo "pending")
        if [[ "${step_status}" == "complete" ]]; then
          # Step finished, move to next
          run_pipeline $((current + 1))
        else
          # Step was running or pending, re-run it
          log_warn "Resuming interrupted step ${current} (status: ${step_status})"
          run_pipeline "${current}"
        fi
      fi
      ;;
    --status)
      show_status
      ;;
    "")
      run_pipeline 1
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"

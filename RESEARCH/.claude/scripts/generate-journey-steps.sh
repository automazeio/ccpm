#!/usr/bin/env bash
#
# generate-journey-steps.sh - Generate detailed journey steps from high-level definitions
#
# Uses a hybrid approach:
#   Phase 1: LLM decomposes journey goal into ordered steps
#   Phase 2: Playwright discovers UI elements/routes
#   Phase 3: LLM generates schema-compliant journey_steps_detailed records
#   Phase 4: Validation and insertion
#
# Usage:
#   ./generate-journey-steps.sh <session-name> [journey-id]
#
# Examples:
#   ./generate-journey-steps.sh finance-personal           # All journeys
#   ./generate-journey-steps.sh finance-personal J-001     # Single journey

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
log_success() { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $*"; }
log_error() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $*"; }

# Load environment
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  source "${PROJECT_ROOT}/.env"
fi

SESSION="${1:-}"
JOURNEY_FILTER="${2:-}"

if [[ -z "${SESSION}" ]]; then
  echo "Usage: $0 <session-name> [journey-id]"
  exit 1
fi

# Database connection
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_DB="${POSTGRES_DB:-${SESSION}}"

db_query() {
  local query="$1"
  PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -t -A -c "${query}" 2>/dev/null || echo ""
}

db_execute() {
  local query="$1"
  PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -c "${query}" > /dev/null 2>&1
}

# Get pages from database for context
get_pages_context() {
  db_query "SELECT json_agg(json_build_object(
    'page_name', page_name,
    'route', route,
    'description', description
  )) FROM page WHERE session_name='${SESSION}'"
}

# Get journey details
get_journey() {
  local journey_id="$1"
  db_query "SELECT json_build_object(
    'id', id,
    'journey_id', journey_id,
    'name', name,
    'actor', actor,
    'actor_description', actor_description,
    'trigger_event', trigger_event,
    'goal', goal,
    'preconditions', preconditions,
    'postconditions', postconditions,
    'success_criteria', success_criteria,
    'exception_paths', exception_paths,
    'frequency', frequency,
    'complexity', complexity
  ) FROM journey WHERE session_name='${SESSION}' AND journey_id='${journey_id}'"
}

# Phase 1: Decompose journey goal into steps using LLM
phase1_decompose_goal() {
  local journey_json="$1"
  local pages_json="$2"
  local output_file="$3"

  local journey_name=$(echo "$journey_json" | jq -r '.name')
  local journey_goal=$(echo "$journey_json" | jq -r '.goal')
  local journey_actor=$(echo "$journey_json" | jq -r '.actor // "User"')
  local journey_trigger=$(echo "$journey_json" | jq -r '.trigger_event // ""')
  local journey_preconditions=$(echo "$journey_json" | jq -r '.preconditions // ""')
  local journey_success=$(echo "$journey_json" | jq -c '.success_criteria // []')

  log "Phase 1: Decomposing '${journey_name}' into steps..."

  # Create prompt for Claude
  local prompt_file=$(mktemp)
  cat > "${prompt_file}" << PROMPT
You are a senior software test automation engineer. Decompose this user journey into ordered, atomic test steps.

JOURNEY DEFINITION:
- Name: ${journey_name}
- Actor: ${journey_actor}
- Trigger: ${journey_trigger}
- Goal: ${journey_goal}
- Preconditions: ${journey_preconditions}
- Success Criteria: ${journey_success}

AVAILABLE PAGES IN THE APPLICATION:
${pages_json}

OUTPUT REQUIREMENTS:
Generate a JSON array of steps. Each step should be specific and testable.
For a finance app, typical steps include: navigate to page, click button, fill form field, submit form, verify result.

OUTPUT FORMAT (JSON only, no explanation):
{
  "journey_name": "${journey_name}",
  "steps": [
    {
      "step_number": 1,
      "step_name": "Short descriptive name",
      "user_action": "What the user does (e.g., 'Click Add Transaction button')",
      "user_intent": "Why they do it",
      "expected_outcome": "What should happen",
      "page_route": "Route from available pages (e.g., '/transactions')",
      "ui_component_type": "button|input|select|link|form|table|card",
      "ui_component_name": "Component identifier",
      "is_decision_point": false,
      "is_form_submission": false
    }
  ]
}

Generate 3-8 steps that cover the complete journey from start to goal completion.
PROMPT

  # Call Claude CLI to generate steps
  local response
  response=$(claude --print -p "$(cat "${prompt_file}")" 2>/dev/null) || {
    log_error "Claude CLI failed"
    rm -f "${prompt_file}"
    return 1
  }
  rm -f "${prompt_file}"

  # Extract JSON from response (handle markdown code blocks)
  local json_output
  json_output=$(echo "$response" | sed -n '/^{/,/^}/p' | head -100)

  if [[ -z "$json_output" ]] || ! echo "$json_output" | jq . > /dev/null 2>&1; then
    # Try extracting from code block
    json_output=$(echo "$response" | sed -n '/```json/,/```/p' | sed '1d;$d')
  fi

  if [[ -z "$json_output" ]] || ! echo "$json_output" | jq . > /dev/null 2>&1; then
    log_error "Failed to parse LLM response as JSON"
    echo "$response" > "${output_file}.error"
    return 1
  fi

  echo "$json_output" > "${output_file}"
  local step_count=$(echo "$json_output" | jq '.steps | length')
  log_success "Generated ${step_count} steps"
}

# Phase 2: Discover UI elements using Playwright (optional enhancement)
phase2_discover_elements() {
  local steps_file="$1"
  local base_url="${2:-http://localhost:5173}"

  log "Phase 2: UI element discovery (using step definitions)..."

  # For now, we use the LLM-generated steps directly
  # In a more advanced implementation, we would:
  # 1. Navigate to each page_route with Playwright
  # 2. Extract actual element selectors from the DOM
  # 3. Update the steps with real locators

  # Check if app is running
  if curl -s "${base_url}" > /dev/null 2>&1; then
    log_success "Application accessible at ${base_url}"
  else
    log_warn "Application not running at ${base_url} - using LLM-generated selectors"
  fi
}

# Phase 3: Generate journey_steps_detailed records
phase3_generate_detailed_steps() {
  local journey_json="$1"
  local steps_file="$2"
  local output_file="$3"

  log "Phase 3: Generating journey_steps_detailed records..."

  local journey_db_id=$(echo "$journey_json" | jq -r '.id')
  local steps_json=$(cat "$steps_file")

  # Transform LLM steps into journey_steps_detailed format
  local detailed_steps=$(echo "$steps_json" | jq --arg jid "$journey_db_id" '
    .steps | to_entries | map({
      journey_id: ($jid | tonumber),
      step_number: (.value.step_number // (.key + 1)),
      step_name: .value.step_name,
      step_description: .value.expected_outcome,
      user_action: .value.user_action,
      user_intent: .value.user_intent,
      user_decision_point: (.value.is_decision_point // false),
      ui_component_type: .value.ui_component_type,
      ui_component_name: .value.ui_component_name,
      ui_page_route: .value.page_route,
      frontend_event_type: (if .value.ui_component_type == "button" then "click"
                           elif .value.ui_component_type == "input" then "input"
                           elif .value.ui_component_type == "form" then "submit"
                           else "interaction" end),
      is_optional: false,
      is_automated: false,
      requires_confirmation: .value.is_form_submission
    })
  ')

  echo "$detailed_steps" > "${output_file}"
  local count=$(echo "$detailed_steps" | jq 'length')
  log_success "Generated ${count} detailed step records"
}

# Phase 4: Validate and insert into database
phase4_insert_steps() {
  local journey_json="$1"
  local detailed_steps_file="$2"

  log "Phase 4: Validating and inserting steps..."

  local journey_db_id=$(echo "$journey_json" | jq -r '.id')
  local journey_id=$(echo "$journey_json" | jq -r '.journey_id')

  # Check if steps already exist
  local existing=$(db_query "SELECT COUNT(*) FROM journey_steps_detailed WHERE journey_id=${journey_db_id}")
  if [[ "${existing}" -gt 0 ]]; then
    log_warn "Journey ${journey_id} already has ${existing} steps - skipping (use --force to overwrite)"
    return 0
  fi

  # Insert each step
  local steps=$(cat "$detailed_steps_file")
  local count=0
  local errors=0

  echo "$steps" | jq -c '.[]' | while read -r step; do
    local step_number=$(echo "$step" | jq -r '.step_number')
    local step_name=$(echo "$step" | jq -r '.step_name' | sed "s/'/''/g")
    local step_desc=$(echo "$step" | jq -r '.step_description // ""' | sed "s/'/''/g")
    local user_action=$(echo "$step" | jq -r '.user_action' | sed "s/'/''/g")
    local user_intent=$(echo "$step" | jq -r '.user_intent // ""' | sed "s/'/''/g")
    local decision_point=$(echo "$step" | jq -r '.user_decision_point // false')
    local ui_type=$(echo "$step" | jq -r '.ui_component_type // ""')
    local ui_name=$(echo "$step" | jq -r '.ui_component_name // ""' | sed "s/'/''/g")
    local ui_route=$(echo "$step" | jq -r '.ui_page_route // ""')
    local event_type=$(echo "$step" | jq -r '.frontend_event_type // ""')
    local is_optional=$(echo "$step" | jq -r '.is_optional // false')
    local requires_confirm=$(echo "$step" | jq -r '.requires_confirmation // false')

    local sql="INSERT INTO journey_steps_detailed (
      journey_id, step_number, step_name, step_description,
      user_action, user_intent, user_decision_point,
      ui_component_type, ui_component_name, ui_page_route,
      frontend_event_type, is_optional, requires_confirmation
    ) VALUES (
      ${journey_db_id}, ${step_number}, '${step_name}', '${step_desc}',
      '${user_action}', '${user_intent}', ${decision_point},
      '${ui_type}', '${ui_name}', '${ui_route}',
      '${event_type}', ${is_optional}, ${requires_confirm}
    ) ON CONFLICT (journey_id, step_number) DO UPDATE SET
      step_name = EXCLUDED.step_name,
      user_action = EXCLUDED.user_action,
      updated_at = NOW()"

    if db_execute "$sql"; then
      ((++count))
    else
      ((++errors))
      log_error "Failed to insert step ${step_number}"
    fi
  done

  # Verify insertion
  local inserted=$(db_query "SELECT COUNT(*) FROM journey_steps_detailed WHERE journey_id=${journey_db_id}")
  log_success "Inserted ${inserted} steps for journey ${journey_id}"
}

# Main processing
main() {
  echo ""
  echo "========================================"
  echo "Generate Journey Steps: ${SESSION}"
  echo "========================================"
  echo ""

  # Get pages context
  local pages_json
  pages_json=$(get_pages_context)
  if [[ -z "$pages_json" ]] || [[ "$pages_json" == "null" ]]; then
    pages_json="[]"
    log_warn "No pages found in database - LLM will infer routes"
  fi

  # Get journeys to process
  local journey_query="SELECT journey_id FROM journey WHERE session_name='${SESSION}'"
  if [[ -n "${JOURNEY_FILTER}" ]]; then
    journey_query="${journey_query} AND journey_id='${JOURNEY_FILTER}'"
  fi

  local journeys
  journeys=$(db_query "${journey_query}")

  if [[ -z "$journeys" ]]; then
    log_error "No journeys found for session: ${SESSION}"
    exit 1
  fi

  local total=0
  local success=0
  local failed=0

  # Create temp directory for intermediate files
  local temp_dir=$(mktemp -d)
  trap "rm -rf ${temp_dir}" EXIT

  for journey_id in $journeys; do
    [[ -z "$journey_id" ]] && continue
    ((++total))

    log "Processing journey: ${journey_id}"

    # Get journey details
    local journey_json
    journey_json=$(get_journey "$journey_id")

    if [[ -z "$journey_json" ]] || [[ "$journey_json" == "null" ]]; then
      log_error "Failed to fetch journey: ${journey_id}"
      ((++failed))
      continue
    fi

    local steps_file="${temp_dir}/${journey_id}-steps.json"
    local detailed_file="${temp_dir}/${journey_id}-detailed.json"

    # Phase 1: Decompose goal
    if ! phase1_decompose_goal "$journey_json" "$pages_json" "$steps_file"; then
      log_error "Phase 1 failed for ${journey_id}"
      ((++failed))
      continue
    fi

    # Phase 2: Discover UI elements (optional)
    phase2_discover_elements "$steps_file"

    # Phase 3: Generate detailed steps
    if ! phase3_generate_detailed_steps "$journey_json" "$steps_file" "$detailed_file"; then
      log_error "Phase 3 failed for ${journey_id}"
      ((++failed))
      continue
    fi

    # Phase 4: Insert into database
    if ! phase4_insert_steps "$journey_json" "$detailed_file"; then
      log_error "Phase 4 failed for ${journey_id}"
      ((++failed))
      continue
    fi

    ((++success))
    echo ""
  done

  echo "========================================"
  echo "Complete"
  echo "========================================"
  echo ""
  echo "  Total journeys: ${total}"
  echo "  Successful:     ${success}"
  echo "  Failed:         ${failed}"
  echo ""

  # Show summary
  local total_steps=$(db_query "SELECT COUNT(*) FROM journey_steps_detailed jsd
    JOIN journey j ON jsd.journey_id = j.id
    WHERE j.session_name='${SESSION}'")
  echo "  Total steps in database: ${total_steps}"
  echo ""
}

main "$@"

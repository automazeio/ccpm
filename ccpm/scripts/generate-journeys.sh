#!/bin/bash
# generate-journeys.sh - Generate user journeys from pipeline artifacts
#
# Called by Step 13 of feature_interrogate.sh
# Implements the 4-phase journey generation architecture:
#   Phase A: Discovery - Extract journeys from requirements
#   Phase B: Decomposition - Break journeys into steps
#   Phase C: Enrichment - Add backend layer details
#   Phase D: Validation - Insert to database
#
# Usage:
#   ./generate-journeys.sh <session_name> <session_dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Extract the first valid JSON object from text that may contain markdown fences
# and other non-JSON content. Handles multi-line JSON.
extract_json_object() {
  local fallback="${1:-{\}}"
  python3 -c "
import json, re, sys
text = sys.stdin.read()
# Strip markdown code fences
text = re.sub(r'^\`\`\`[a-z]*\s*$', '', text, flags=re.MULTILINE)
# Find first { and match to closing }
depth = 0
start = -1
for i, ch in enumerate(text):
    if ch == '{':
        if start == -1:
            start = i
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0 and start != -1:
            try:
                obj = json.loads(text[start:i+1])
                print(json.dumps(obj))
                sys.exit(0)
            except json.JSONDecodeError:
                start = -1
                continue
print('$fallback')
" 2>/dev/null || echo "$fallback"
}

# =============================================================================
# Configuration
# =============================================================================

MAX_JOURNEYS=15
MAX_STEPS_PER_JOURNEY=15
MIN_JOURNEYS=1

# Database connection (uses CCPM pattern)
DB_NAMESPACE="cattle-erp"
DB_POD_PREFIX="postgresql-cattle-erp"
DB_NAME="cattle_erp"
DB_USER="postgres"
DB_PASS="upj3RsNuqy"

# =============================================================================
# Logging Functions
# =============================================================================

log() {
  echo -e "  ${BLUE}▸${NC} $1"
}

log_success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

log_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "  ${RED}✗${NC} $1" >&2
}

# =============================================================================
# Database Functions
# =============================================================================

# Execute SQL against the database
db_exec() {
  local sql="$1"
  PGPASSWORD="$DB_PASS" kubectl exec -n "$DB_NAMESPACE" "${DB_POD_PREFIX}-0" -- \
    psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "$sql" 2>/dev/null
}

# Execute SQL from a file
db_exec_file() {
  local sql_file="$1"
  PGPASSWORD="$DB_PASS" kubectl exec -n "$DB_NAMESPACE" "${DB_POD_PREFIX}-0" -i -- \
    psql -U "$DB_USER" -d "$DB_NAME" -t -A < "$sql_file" 2>/dev/null
}

# Ensure journey tables exist
ensure_journey_tables() {
  local migration_file="$PROJECT_ROOT/backend/migrations/034_journey_tables.sql"

  if [ -f "$migration_file" ]; then
    log "Ensuring journey tables exist..."
    db_exec_file "$migration_file" || {
      log_warn "Could not run migration - tables may already exist"
    }
  fi
}

# Insert a journey into the database
insert_journey() {
  local session_name="$1"
  local journey_json="$2"

  # Extract fields from JSON
  local name=$(echo "$journey_json" | jq -r '.name // empty')
  local actor=$(echo "$journey_json" | jq -r '.actor // empty')
  local trigger_event=$(echo "$journey_json" | jq -r '.trigger_event // empty')
  local goal=$(echo "$journey_json" | jq -r '.goal // empty')
  local preconditions=$(echo "$journey_json" | jq -r '.preconditions // empty')
  local postconditions=$(echo "$journey_json" | jq -r '.postconditions // empty')
  local frequency=$(echo "$journey_json" | jq -r '.frequency // empty')
  local complexity=$(echo "$journey_json" | jq -r '.complexity // empty')

  # Escape single quotes for SQL
  name=$(echo "$name" | sed "s/'/''/g")
  actor=$(echo "$actor" | sed "s/'/''/g")
  trigger_event=$(echo "$trigger_event" | sed "s/'/''/g")
  goal=$(echo "$goal" | sed "s/'/''/g")
  preconditions=$(echo "$preconditions" | sed "s/'/''/g")
  postconditions=$(echo "$postconditions" | sed "s/'/''/g")

  # Extract required_privileges (array of privilege codes)
  local required_privs
  required_privs=$(echo "$journey_json" | jq -c '.required_privileges // []')

  # Use upsert function
  local journey_id
  journey_id=$(db_exec "SELECT upsert_journey(
    '$session_name',
    '$name',
    NULLIF('$actor', ''),
    NULLIF('$trigger_event', ''),
    NULLIF('$goal', ''),
    NULLIF('$preconditions', ''),
    NULLIF('$postconditions', ''),
    NULLIF('$frequency', ''),
    NULLIF('$complexity', ''),
    'generated'
  );")

  # Update required_privileges (upsert_journey doesn't accept this param)
  if [ "$required_privs" != "[]" ] && [ -n "$required_privs" ]; then
    db_exec "UPDATE journey SET required_privileges = ARRAY(SELECT jsonb_array_elements_text('$required_privs'::jsonb))
             WHERE session_name='$session_name' AND name='$name';" 2>/dev/null || true
  fi

  echo "$journey_id"
}

# Insert a journey step into the database
insert_journey_step() {
  local journey_db_id="$1"
  local step_json="$2"

  # Extract fields from JSON
  local step_number=$(echo "$step_json" | jq -r '.step_number // 1')
  local step_name=$(echo "$step_json" | jq -r '.step_name // "Step"')
  local step_description=$(echo "$step_json" | jq -r '.step_description // empty')
  local user_action=$(echo "$step_json" | jq -r '.user_action // "Action"')
  local user_intent=$(echo "$step_json" | jq -r '.user_intent // empty')
  local ui_component_type=$(echo "$step_json" | jq -r '.ui_component_type // empty')
  local ui_component_name=$(echo "$step_json" | jq -r '.ui_component_name // empty')
  local ui_page_route=$(echo "$step_json" | jq -r '.ui_page_route // empty')
  local frontend_event_type=$(echo "$step_json" | jq -r '.frontend_event_type // empty')
  local api_operation_type=$(echo "$step_json" | jq -r '.api_operation_type // empty')
  local api_endpoint=$(echo "$step_json" | jq -r '.api_endpoint // empty')
  local api_auth_required=$(echo "$step_json" | jq -r '.api_auth_required // true')
  local db_operation=$(echo "$step_json" | jq -r '.db_operation // empty')
  local db_tables_affected=$(echo "$step_json" | jq -c '.db_tables_affected // []')
  local possible_errors=$(echo "$step_json" | jq -c '.possible_errors // []')
  local is_optional=$(echo "$step_json" | jq -r '.is_optional // false')
  local notes=$(echo "$step_json" | jq -r '.notes // empty')

  # Escape single quotes
  step_name=$(echo "$step_name" | sed "s/'/''/g")
  step_description=$(echo "$step_description" | sed "s/'/''/g")
  user_action=$(echo "$user_action" | sed "s/'/''/g")
  user_intent=$(echo "$user_intent" | sed "s/'/''/g")
  ui_component_name=$(echo "$ui_component_name" | sed "s/'/''/g")
  notes=$(echo "$notes" | sed "s/'/''/g")

  # Build INSERT statement
  db_exec "INSERT INTO journey_steps_detailed (
    journey_id, step_number, step_name, step_description,
    user_action, user_intent,
    ui_component_type, ui_component_name, ui_page_route,
    frontend_event_type,
    api_operation_type, api_endpoint, api_auth_required,
    db_operation, db_tables_affected,
    possible_errors, is_optional, notes
  ) VALUES (
    $journey_db_id, $step_number, '$step_name', NULLIF('$step_description', ''),
    '$user_action', NULLIF('$user_intent', ''),
    NULLIF('$ui_component_type', ''), NULLIF('$ui_component_name', ''), NULLIF('$ui_page_route', ''),
    NULLIF('$frontend_event_type', ''),
    NULLIF('$api_operation_type', ''), NULLIF('$api_endpoint', ''), $api_auth_required,
    NULLIF('$db_operation', ''), '$db_tables_affected'::jsonb,
    '$possible_errors'::jsonb, $is_optional, NULLIF('$notes', '')
  ) ON CONFLICT (journey_id, step_number) DO UPDATE SET
    step_name = EXCLUDED.step_name,
    user_action = EXCLUDED.user_action,
    api_endpoint = EXCLUDED.api_endpoint,
    db_operation = EXCLUDED.db_operation,
    db_tables_affected = EXCLUDED.db_tables_affected,
    updated_at = NOW()
  RETURNING id;"
}

# =============================================================================
# Phase A: Journey Discovery
# =============================================================================

discover_journeys() {
  local session_dir="$1"
  local session_name="$2"
  local output_file="$3"

  log "Phase A: Discovering journeys from requirements..."

  local requirements_file="$session_dir/refined-requirements.md"
  local flow_diagram_file="$session_dir/flow-diagram.md"
  local template_file="$PROJECT_ROOT/.claude/templates/journey-prompts/phase-a-discovery.md"

  # Check prerequisites
  if [ ! -f "$requirements_file" ]; then
    log_error "Requirements file not found: $requirements_file"
    return 1
  fi

  # Read content
  local requirements_content
  requirements_content=$(sed '1,/^---$/d; 1,/^---$/d' "$requirements_file" 2>/dev/null || cat "$requirements_file")

  local flow_content=""
  if [ -f "$flow_diagram_file" ]; then
    flow_content=$(cat "$flow_diagram_file")
  fi

  # Build prompt - directly construct instead of template substitution
  # (Template substitution fails with multiline content containing special chars)
  local prompt_file
  prompt_file=$(mktemp)

  # Always use inline prompt construction for reliability
  cat > "$prompt_file" << 'PROMPT_HEADER_EOF'
# Phase A: Journey Discovery Prompt

<role>
You are a senior product analyst extracting user journeys from software requirements.
You understand that a journey represents a complete workflow a specific user performs to achieve a measurable goal.
</role>

<context>
<requirements>
PROMPT_HEADER_EOF

  # Append requirements content
  echo "$requirements_content" >> "$prompt_file"

  cat >> "$prompt_file" << 'PROMPT_MID1_EOF'
</requirements>

<flow_diagram>
PROMPT_MID1_EOF

  # Append flow diagram content
  echo "$flow_content" >> "$prompt_file"

  cat >> "$prompt_file" << PROMPT_MID2_EOF
</flow_diagram>

<session_name>$session_name</session_name>

<privilege_map>
Available privilege codes: $(paste -sd', ' "$session_dir/privilege-codes.txt" 2>/dev/null || echo "admin.all, inventory.view, inventory.edit, inventory.create, inventory.delete, vendors.view, vendors.edit, vendors.create, vendors.delete, orders.view, orders.edit, orders.create, orders.update, orders.delete, orders.approve, orders.workflow, kanban.view, kanban.edit, organizations.view, organizations.create, organizations.edit, organizations.delete, invoices.view, invoices.create, invoices.edit, invoices.delete, users.view, users.edit, users.delete, reports.view, reports.export")
</privilege_map>
</context>

<task>
Extract all distinct user journeys from the requirements and flow diagram.

For each journey, identify:
1. **Actor**: The specific user role performing this journey
2. **Trigger**: What initiates this journey
3. **Goal**: The measurable outcome the user achieves
4. **Preconditions**: What must be true before starting
5. **Postconditions**: What is true after completion
6. **Frequency**: How often this journey occurs
7. **Complexity**: simple (1-3 steps), moderate (4-7 steps), complex (8+ steps)
</task>

<output_format>
Respond with valid JSON only (no markdown, no explanation):

{
  "journeys": [
    {
      "session_name": "$session_name",
      "journey_id": "J-001",
      "name": "verb-noun-format (e.g., Create Organization)",
      "actor": "exact role from requirements",
      "actor_description": "detailed description of who this actor is",
      "trigger_event": "what initiates this journey",
      "goal": "measurable outcome",
      "preconditions": "comma-separated list of preconditions",
      "postconditions": "comma-separated list of postconditions",
      "success_criteria": ["criterion 1", "criterion 2"],
      "exception_paths": ["exception path 1"],
      "frequency": "daily|weekly|monthly|occasional",
      "complexity": "simple|moderate|complex",
      "estimated_duration": "e.g., 2 minutes",
      "priority": "high|medium|low",
      "required_privileges": ["organizations.view", "organizations.edit"]
    }
  ]
}
</output_format>

<constraints>
- Extract journeys that are explicitly supported by the requirements
- Each journey maps to at least one acceptance criterion
- Use exact actor names from requirements (invent no roles)
- Use null for any field that cannot be determined
- Extract 3-15 journeys
- Journey names are unique and use verb-noun format
- Prefix inferred or assumed information with "[INFERRED]"
- Each journey includes required_privileges — the privilege codes from the privilege_map that a user needs to complete the journey
- Map journey actions to privilege codes: viewing pages needs *.view, creating resources needs *.create or *.edit, deleting needs *.delete
- Include organizations.view for any journey that accesses organization-scoped data
</constraints>

<examples>
<example>
Input: "Users can create organizations and invite members"
Output journey:
{
  "name": "Create Organization",
  "actor": "User",
  "trigger_event": "User needs to establish organizational presence",
  "goal": "Organization created with user as owner",
  "preconditions": "User is authenticated, User has no organization",
  "postconditions": "Organization exists, User is owner",
  "frequency": "occasional",
  "complexity": "simple",
  "required_privileges": ["organizations.view", "organizations.create", "organizations.edit"]
}
</example>
</examples>
PROMPT_MID2_EOF

  if false; then
    # Dead code - keeping structure for future template support
    cat > /dev/null << 'PROMPT_EOF'
You are a senior product analyst extracting user journeys.

## Requirements
$requirements_content

## Flow Diagram
$flow_content

## Task
Extract all distinct user journeys. Respond with ONLY valid JSON:

{
  "journeys": [
    {
      "session_name": "$session_name",
      "journey_id": "J-001",
      "name": "verb-noun format",
      "actor": "role from requirements",
      "trigger_event": "what starts this",
      "goal": "measurable outcome",
      "preconditions": "required before starting",
      "postconditions": "true after completion",
      "frequency": "daily|weekly|monthly|occasional",
      "complexity": "simple|moderate|complex"
    }
  ]
}
PROMPT_EOF
  fi

  # Generate using Claude CLI
  if ! command -v claude &> /dev/null; then
    log_error "Claude CLI not available"
    rm -f "$prompt_file"
    return 1
  fi

  local raw_output
  raw_output=$(claude --print --tools "" < "$prompt_file" 2>/dev/null) || {
    log_error "Claude CLI failed for journey discovery"
    rm -f "$prompt_file"
    return 1
  }

  # Extract JSON from response (handles multi-line JSON and markdown fences)
  local json_output
  json_output=$(echo "$raw_output" | extract_json_object '{"journeys":[]}')

  # Validate JSON has journeys array
  if echo "$json_output" | jq '.journeys' > /dev/null 2>&1; then
    echo "$json_output" > "$output_file"
    local journey_count
    journey_count=$(echo "$json_output" | jq '.journeys | length')
    log_success "Discovered $journey_count journeys"
  else
    log_warn "Invalid JSON response, using fallback"
    echo '{"journeys":[]}' > "$output_file"
  fi

  rm -f "$prompt_file"
}

# =============================================================================
# Phase B: Journey Decomposition
# =============================================================================

decompose_journey() {
  local session_dir="$1"
  local journey_json="$2"
  local output_file="$3"

  local journey_name
  journey_name=$(echo "$journey_json" | jq -r '.name')
  log "Phase B: Decomposing journey: $journey_name"

  local flow_diagram_file="$session_dir/flow-diagram.md"
  local template_file="$PROJECT_ROOT/.claude/templates/journey-prompts/phase-b-decomposition.md"

  # Extract endpoint mapping from flow diagram
  local endpoint_mapping=""
  if [ -f "$flow_diagram_file" ]; then
    endpoint_mapping=$(grep -E "^- /api/v1" "$flow_diagram_file" || echo "")
  fi

  local flow_content=""
  if [ -f "$flow_diagram_file" ]; then
    flow_content=$(cat "$flow_diagram_file")
  fi

  # Build prompt
  local prompt_file
  prompt_file=$(mktemp)

  cat > "$prompt_file" << PROMPT_EOF
<role>
You are a senior UX engineer. Decompose user journeys into ordered, atomic steps with full stack traceability.
</role>

<journey>
$journey_json
</journey>

<endpoint_mapping>
$endpoint_mapping
</endpoint_mapping>

<flow_diagram>
$flow_content
</flow_diagram>

<task>
Break this journey into individual steps. For each step, trace the complete flow from UI action through API to database.
Match API endpoints exactly from the endpoint mapping above.
</task>

<output_format>
Respond with ONLY valid JSON (no explanation, no markdown fences):

{
  "journey_name": "$journey_name",
  "steps": [
    {
      "step_number": 1,
      "step_name": "Navigate to Page",
      "user_action": "Click link",
      "user_intent": "Access feature",
      "ui_component_type": "link",
      "ui_component_name": "ComponentName",
      "ui_page_route": "/route",
      "frontend_event_type": "click",
      "api_operation_type": "GET",
      "api_endpoint": "/api/v1/resource",
      "api_auth_required": true,
      "db_operation": "read",
      "db_tables_affected": ["table_name"],
      "possible_errors": [{"code": "404", "message": "Not found"}],
      "is_optional": false,
      "notes": null
    }
  ]
}

Use null for unknown fields.
</output_format>
PROMPT_EOF

  # Generate using Claude CLI
  if ! command -v claude &> /dev/null; then
    echo '{"journey_name":"'"$journey_name"'","steps":[]}' > "$output_file"
    rm -f "$prompt_file"
    return 0
  fi

  local raw_output
  raw_output=$(claude --print --tools "" < "$prompt_file" 2>/dev/null) || {
    log_warn "Step decomposition failed for: $journey_name"
    echo '{"journey_name":"'"$journey_name"'","steps":[]}' > "$output_file"
    rm -f "$prompt_file"
    return 0
  }

  # Extract JSON from response (handles multi-line JSON and markdown fences)
  local json_output
  json_output=$(echo "$raw_output" | extract_json_object '{"steps":[]}')

  if echo "$json_output" | jq '.steps' > /dev/null 2>&1; then
    echo "$json_output" > "$output_file"
    local step_count
    step_count=$(echo "$json_output" | jq '.steps | length')
    log_success "  $journey_name: $step_count steps"
  else
    echo '{"journey_name":"'"$journey_name"'","steps":[]}' > "$output_file"
  fi

  rm -f "$prompt_file"
}

# =============================================================================
# Phase D: Validation and Database Insert
# =============================================================================

validate_and_insert() {
  local session_name="$1"
  local session_dir="$2"
  local journeys_file="$session_dir/journeys.json"

  log "Phase D: Validating and inserting to database..."

  # Ensure tables exist
  ensure_journey_tables

  if [ ! -f "$journeys_file" ]; then
    log_error "Journeys file not found: $journeys_file"
    return 1
  fi

  local journey_count
  journey_count=$(jq '.journeys | length' "$journeys_file" 2>/dev/null || echo 0)

  if [ "$journey_count" -eq 0 ]; then
    log_warn "No journeys to insert"
    return 0
  fi

  local inserted_journeys=0
  local inserted_steps=0

  # Process each journey
  for i in $(seq 0 $((journey_count - 1))); do
    local journey_json
    journey_json=$(jq ".journeys[$i]" "$journeys_file")

    local journey_name
    journey_name=$(echo "$journey_json" | jq -r '.name')

    # Insert journey
    local journey_db_id
    journey_db_id=$(insert_journey "$session_name" "$journey_json" 2>/dev/null) || {
      log_warn "Failed to insert journey: $journey_name"
      continue
    }

    if [ -n "$journey_db_id" ] && [ "$journey_db_id" != "null" ]; then
      inserted_journeys=$((inserted_journeys + 1))

      # Check for steps file
      local steps_file="$session_dir/steps-J-$(printf '%03d' $((i + 1))).json"
      if [ -f "$steps_file" ]; then
        local step_count
        step_count=$(jq '.steps | length' "$steps_file" 2>/dev/null || echo 0)

        for j in $(seq 0 $((step_count - 1))); do
          local step_json
          step_json=$(jq ".steps[$j]" "$steps_file")

          insert_journey_step "$journey_db_id" "$step_json" > /dev/null 2>&1 && {
            inserted_steps=$((inserted_steps + 1))
          }
        done
      fi
    fi
  done

  log_success "Inserted $inserted_journeys journeys, $inserted_steps steps"

  # Return counts
  echo "$inserted_journeys:$inserted_steps"
}

# =============================================================================
# Main Generation Function
# =============================================================================

generate_user_journeys() {
  local session_name="$1"
  local session_dir="$2"

  log "Starting journey generation for: $session_name"

  # Phase A: Discover journeys
  local journeys_file="$session_dir/journeys.json"
  discover_journeys "$session_dir" "$session_name" "$journeys_file" || {
    log_error "Journey discovery failed"
    return 1
  }

  # Check journey count
  local journey_count
  journey_count=$(jq '.journeys | length' "$journeys_file" 2>/dev/null || echo 0)

  if [ "$journey_count" -lt "$MIN_JOURNEYS" ]; then
    log_warn "Only $journey_count journeys found (minimum: $MIN_JOURNEYS)"
  fi

  # Phase B: Decompose each journey
  for i in $(seq 0 $((journey_count - 1))); do
    local journey_json
    journey_json=$(jq ".journeys[$i]" "$journeys_file")

    local journey_id="J-$(printf '%03d' $((i + 1)))"
    local steps_file="$session_dir/steps-$journey_id.json"

    decompose_journey "$session_dir" "$journey_json" "$steps_file"

    # Rate limiting to avoid Claude API issues
    sleep 1
  done

  # Phase C: Enrichment (simplified - just validate endpoint mapping)
  log "Phase C: Validating endpoint mappings..."
  local valid_endpoints=0
  local flow_diagram="$session_dir/flow-diagram.md"

  if [ -f "$flow_diagram" ]; then
    for steps_file in "$session_dir"/steps-J-*.json; do
      [ -f "$steps_file" ] || continue
      local step_count
      step_count=$(jq '.steps | length' "$steps_file" 2>/dev/null || echo 0)

      for j in $(seq 0 $((step_count - 1))); do
        local endpoint
        endpoint=$(jq -r ".steps[$j].api_endpoint // empty" "$steps_file")

        if [ -n "$endpoint" ] && grep -q "$endpoint" "$flow_diagram"; then
          valid_endpoints=$((valid_endpoints + 1))
        fi
      done
    done
  fi
  log_success "Validated $valid_endpoints endpoint mappings"

  # Phase D: Insert to database
  local result
  result=$(validate_and_insert "$session_name" "$session_dir") || {
    log_warn "Database insertion had issues"
    result="0:0"
  }

  local inserted_journeys="${result%%:*}"
  local inserted_steps="${result##*:}"

  # Generate report
  generate_journey_report "$session_dir" "$journey_count" "$inserted_journeys" "$inserted_steps"

  echo "$inserted_journeys:$inserted_steps"
}

# =============================================================================
# Report Generation
# =============================================================================

generate_journey_report() {
  local session_dir="$1"
  local discovered="$2"
  local inserted_journeys="$3"
  local inserted_steps="$4"

  local report_file="$session_dir/journey-generation-report.md"

  {
    printf "# Journey Generation Report\n\n"
    printf "**Generated:** %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    printf "## Summary\n\n"
    printf "| Metric | Count |\n"
    printf "|--------|-------|\n"
    printf "| Journeys Discovered | %s |\n" "$discovered"
    printf "| Journeys Inserted | %s |\n" "$inserted_journeys"
    printf "| Steps Generated | %s |\n\n" "$inserted_steps"

    printf "## Journeys\n\n"

    if [ -f "$session_dir/journeys.json" ]; then
      local count
      count=$(jq '.journeys | length' "$session_dir/journeys.json")

      for i in $(seq 0 $((count - 1))); do
        local name
        name=$(jq -r ".journeys[$i].name" "$session_dir/journeys.json")
        local actor
        actor=$(jq -r ".journeys[$i].actor // \"Unknown\"" "$session_dir/journeys.json")
        local goal
        goal=$(jq -r ".journeys[$i].goal // \"N/A\"" "$session_dir/journeys.json")

        printf "### J-%03d: %s\n\n" "$((i + 1))" "$name"
        printf -- "- **Actor:** %s\n" "$actor"
        printf -- "- **Goal:** %s\n\n" "$goal"

        # List steps if available
        local steps_file="$session_dir/steps-J-$(printf '%03d' $((i + 1))).json"
        if [ -f "$steps_file" ]; then
          local step_count
          step_count=$(jq '.steps | length' "$steps_file" 2>/dev/null || echo 0)

          printf "| Step | Action | Endpoint | DB Operation |\n"
          printf "|------|--------|----------|-------------|\n"

          for j in $(seq 0 $((step_count - 1))); do
            local step_num=$((j + 1))
            local action
            action=$(jq -r ".steps[$j].user_action // \"N/A\"" "$steps_file")
            local endpoint
            endpoint=$(jq -r ".steps[$j].api_endpoint // \"-\"" "$steps_file")
            local db_op
            db_op=$(jq -r ".steps[$j].db_operation // \"-\"" "$steps_file")

            printf "| %d | %s | %s | %s |\n" "$step_num" "$action" "$endpoint" "$db_op"
          done
          printf "\n"
        fi
      done
    fi

    printf "## Database Tables\n\n"
    printf -- "- \`journey\` - Journey headers\n"
    printf -- "- \`journey_steps_detailed\` - Step details with full traceability\n\n"

    printf "## Next Steps\n\n"
    printf "1. Review generated journeys in the database\n"
    printf "2. Use \`/pm:generate-personas\` to create test personas\n"
    printf "3. Use \`/pm:test-journey\` to run journey tests\n"
  } > "$report_file"
}

# =============================================================================
# Entry Point
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <session_name> <session_dir>"
    exit 1
  fi

  SESSION_NAME="$1"
  SESSION_DIR="$2"

  generate_user_journeys "$SESSION_NAME" "$SESSION_DIR"
fi

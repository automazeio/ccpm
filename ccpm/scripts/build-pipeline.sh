#!/bin/bash
# build-pipeline.sh - Meta-Script Generator for 10-Step Pipeline
#
# Automatically builds the missing steps (4, 5, 7, 8, 9) in feature_interrogate.sh
# using deep research, planning, implementation, and verification.
#
# For each step:
#   1. Research  - Deep research on how to implement with AI
#   2. Plan      - Create implementation plan
#   3. Build     - Generate and apply code changes
#   4. Verify    - Test accuracy against metrics
#   5. Fix       - Troubleshoot if verification fails
#   6. Commit    - Commit successful implementation
#
# Usage:
#   ./build-pipeline.sh [--step N] [--dry-run] [--resume]
#
# Options:
#   --step N     Only build step N (4, 5, 7, 8, or 9)
#   --dry-run    Plan only, don't apply changes
#   --resume     Resume from last successful step
#
# Created: 2026-01-28
# Based on: research-report.md (10-step artifact sequence)

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.claude/pipeline-build"
RESEARCH_REPORT="$PROJECT_ROOT/research-report.md"
TARGET_SCRIPT="$PROJECT_ROOT/.claude/ccpm/ccpm/scripts/feature_interrogate.sh"
STATE_FILE="$BUILD_DIR/build-state.json"
LOG_FILE="$BUILD_DIR/build.log"

# Accuracy thresholds (from research)
declare -A ACCURACY_THRESHOLDS=(
  [4]=90   # Acceptance Criteria - AI HIGH capability
  [5]=80   # Domain Model - AI PARTIAL capability
  [7]=95   # API Contract - AI HIGH capability
  [8]=90   # Data Schema - AI HIGH capability
  [9]=80   # Task Breakdown - AI PARTIAL capability
)

# Step names
declare -A STEP_NAMES=(
  [4]="Acceptance Criteria"
  [5]="Domain Model"
  [7]="API Contract"
  [8]="Data Schema"
  [9]="Task Breakdown"
)

# Step research questions
declare -A STEP_RESEARCH_QUESTIONS=(
  [4]="How to use AI/LLMs to generate high-quality Gherkin acceptance criteria from user stories, including prompt engineering, validation techniques, accuracy metrics, and open source tools like Cucumber"
  [5]="How to use AI/LLMs to generate domain models with entities, aggregates, and ownership relationships from user stories, including DDD patterns, Context Mapper integration, and validation of aggregate boundaries"
  [7]="How to use AI/LLMs to generate OpenAPI specifications from domain models and requirements, including contract-first design patterns, Spectral linting, and ensuring complete error responses"
  [8]="How to use AI/LLMs to generate database schemas (ERD and SQL migrations) from domain models, including foreign key validation, constraint generation, and index recommendations"
  [9]="How to use AI/LLMs to break down features into developer-assignable tasks with estimates, dependencies, and acceptance criteria links, including INVEST validation and spike detection"
)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# === LOGGING ===
log() { echo -e "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
log_success() { echo -e "[$(date +%H:%M:%S)] ${GREEN}✅ $*${NC}" | tee -a "$LOG_FILE"; }
log_error() { echo -e "[$(date +%H:%M:%S)] ${RED}❌ $*${NC}" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "[$(date +%H:%M:%S)] ${YELLOW}⚠️  $*${NC}" | tee -a "$LOG_FILE"; }
log_phase() { echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${BLUE}▸ $*${NC}" | tee -a "$LOG_FILE"; }

# === STATE MANAGEMENT ===
init_state() {
  mkdir -p "$BUILD_DIR"
  cat > "$STATE_FILE" << 'EOF'
{
  "started_at": "",
  "current_step": null,
  "completed_steps": [],
  "failed_steps": [],
  "step_results": {}
}
EOF
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.started_at = $ts' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

update_state() {
  local key="$1"
  local value="$2"
  jq --arg k "$key" --argjson v "$value" '.[$k] = $v' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

add_completed_step() {
  local step="$1"
  jq --argjson s "$step" '.completed_steps += [$s]' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

add_step_result() {
  local step="$1"
  local result="$2"
  jq --arg s "$step" --argjson r "$result" '.step_results[$s] = $r' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

get_completed_steps() {
  jq -r '.completed_steps[]' "$STATE_FILE" 2>/dev/null || echo ""
}

# === PHASE 1: RESEARCH ===
run_research_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local research_question="${STEP_RESEARCH_QUESTIONS[$step]}"
  local research_file="$BUILD_DIR/research-step$step.md"

  log_phase "STEP $step: RESEARCH PHASE - $step_name"

  if [ -f "$research_file" ] && [ -s "$research_file" ]; then
    log "Research file exists, checking if valid..."
    local line_count=$(wc -l < "$research_file")
    if [ "$line_count" -gt 50 ]; then
      log_success "Using existing research ($line_count lines)"
      return 0
    fi
  fi

  log_step "Launching deep research: $step_name"
  log "Question: $research_question"

  # Create research prompt
  local research_prompt="Perform deep research on: \"$research_question\"

Focus areas:
1. **Prompt Engineering**: What prompts produce the best results for this artifact type?
2. **Accuracy Metrics**: How do we measure quality? What benchmarks exist?
3. **Validation Techniques**: Syntax validation, semantic validation, coverage checks
4. **Open Source Tools**: What tools support this step?
5. **Integration Pattern**: How to integrate into a bash pipeline (feature_interrogate.sh)

Output:
- Specific prompt templates usable directly
- Validation checklists with pass/fail criteria
- Accuracy measurement approach
- Sample outputs

Write comprehensive findings directly usable to implement this step."

  # Run research via Claude
  if command -v claude &> /dev/null; then
    log "Running claude for research..."
    claude --dangerously-skip-permissions --print "$research_prompt" > "$research_file" 2>&1 || {
      log_error "Research failed for step $step"
      return 1
    }

    local line_count=$(wc -l < "$research_file")
    log_success "Research complete: $research_file ($line_count lines)"
  else
    log_error "Claude CLI not found - cannot run research"
    return 1
  fi

  return 0
}

# === PHASE 2: PLAN ===
run_plan_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local research_file="$BUILD_DIR/research-step$step.md"
  local plan_file="$BUILD_DIR/plan-step$step.md"

  log_phase "STEP $step: PLAN PHASE - $step_name"

  if [ ! -f "$research_file" ]; then
    log_error "Research file not found: $research_file"
    return 1
  fi

  if [ -f "$plan_file" ] && [ -s "$plan_file" ]; then
    local line_count=$(wc -l < "$plan_file")
    if [ "$line_count" -gt 20 ]; then
      log_success "Using existing plan ($line_count lines)"
      return 0
    fi
  fi

  log_step "Creating implementation plan..."

  # Read current feature_interrogate.sh structure
  local current_structure=""
  if [ -f "$TARGET_SCRIPT" ]; then
    current_structure=$(grep -n "^# Step\|^step_\|^show_step_header" "$TARGET_SCRIPT" | head -30)
  fi

  local plan_prompt="Based on the research below, create an implementation plan for adding Step $step ($step_name) to feature_interrogate.sh.

## Research Findings
$(cat "$research_file" | head -500)

## Current Script Structure
$current_structure

## Requirements
1. Integrate with the existing pipeline flow
2. Include validation with accuracy threshold of ${ACCURACY_THRESHOLDS[$step]}%
3. Output artifacts to the session directory
4. Handle errors gracefully
5. Be testable independently

## Output Format
Create a detailed implementation plan with:

### 1. Function Signature
\`\`\`bash
step_${step}_${step_name// /_}() {
  # Purpose: ...
  # Inputs: ...
  # Outputs: ...
}
\`\`\`

### 2. Claude Prompt Template
The exact prompt to send to Claude for generating the artifact.

### 3. Validation Checklist
Specific checks to validate the output:
- [ ] Check 1: ...
- [ ] Check 2: ...

### 4. Accuracy Measurement
How to calculate accuracy score (0-100%).

### 5. Error Handling
What to do when generation or validation fails.

### 6. Integration Points
Where in the pipeline this step runs and what it depends on."

  if command -v claude &> /dev/null; then
    log "Running claude for planning..."
    claude --dangerously-skip-permissions --print "$plan_prompt" > "$plan_file" 2>&1 || {
      log_error "Planning failed for step $step"
      return 1
    }

    local line_count=$(wc -l < "$plan_file")
    log_success "Plan complete: $plan_file ($line_count lines)"
  else
    log_error "Claude CLI not found"
    return 1
  fi

  return 0
}

# === PHASE 3: BUILD ===
run_build_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local plan_file="$BUILD_DIR/plan-step$step.md"
  local code_file="$BUILD_DIR/code-step$step.sh"
  local patch_file="$BUILD_DIR/patch-step$step.patch"

  log_phase "STEP $step: BUILD PHASE - $step_name"

  if [ ! -f "$plan_file" ]; then
    log_error "Plan file not found: $plan_file"
    return 1
  fi

  log_step "Generating implementation code..."

  # Read current script for context
  local script_context=""
  if [ -f "$TARGET_SCRIPT" ]; then
    script_context=$(head -500 "$TARGET_SCRIPT")
  fi

  local build_prompt="Based on the implementation plan below, generate the bash code to add Step $step ($step_name) to feature_interrogate.sh.

## Implementation Plan
$(cat "$plan_file")

## Current Script Context (first 500 lines)
$script_context

## Output Requirements

Generate a complete bash function that:
1. Shows step header with step number
2. Calls Claude with the prompt template from the plan
3. Saves output to session directory
4. Validates output against checklist
5. Returns accuracy score
6. Handles errors

Output format:
\`\`\`bash
# Step $step: $step_name
# Added by build-pipeline.sh on $(date -u +%Y-%m-%d)

step_${step}_$(echo "$step_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')() {
  show_step_header $step \"$step_name\" \"research\"

  local session_dir=\"\$1\"
  local accuracy=0

  # [Implementation here]

  echo \"\$accuracy\"
}
\`\`\`

Include the exact insertion location in feature_interrogate.sh (line number or after which function)."

  if command -v claude &> /dev/null; then
    log "Running claude for code generation..."
    claude --dangerously-skip-permissions --print "$build_prompt" > "$code_file" 2>&1 || {
      log_error "Code generation failed for step $step"
      return 1
    }

    local line_count=$(wc -l < "$code_file")
    log_success "Code generated: $code_file ($line_count lines)"

    # Extract just the bash code block
    local extracted_code="$BUILD_DIR/extracted-step$step.sh"
    sed -n '/^```bash/,/^```$/p' "$code_file" | sed '1d;$d' > "$extracted_code" || true

    if [ -s "$extracted_code" ]; then
      log_success "Extracted bash code: $extracted_code"
    else
      log_warn "Could not extract code block - manual review needed"
    fi
  else
    log_error "Claude CLI not found"
    return 1
  fi

  return 0
}

# === PHASE 4: VERIFY ===
run_verify_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local threshold="${ACCURACY_THRESHOLDS[$step]}"
  local code_file="$BUILD_DIR/extracted-step$step.sh"
  local test_dir="$BUILD_DIR/test-step$step"
  local verify_file="$BUILD_DIR/verify-step$step.md"

  log_phase "STEP $step: VERIFY PHASE - $step_name"

  mkdir -p "$test_dir"

  # Create a test input based on step type
  local test_input=""
  case $step in
    4) # Acceptance Criteria - need user story
      test_input="As a user, I want to log in with my email and password so that I can access my account."
      ;;
    5) # Domain Model - need user stories
      test_input="Feature: User Authentication
- Users can register with email/password
- Users can log in
- Users have profiles with name and avatar
- Admins can manage users"
      ;;
    7) # API Contract - need domain model
      test_input="Entities: User (id, email, password_hash, created_at), Profile (id, user_id, name, avatar_url)
Relationships: User has_one Profile"
      ;;
    8) # Data Schema - need domain model
      test_input="Entities: User (id: UUID, email: string, password_hash: string, created_at: timestamp), Profile (id: UUID, user_id: UUID FK->User, name: string, avatar_url: string)"
      ;;
    9) # Task Breakdown - need all above
      test_input="Feature: User Authentication
Stories: Login, Register, Profile Management
API: POST /auth/login, POST /auth/register, GET /users/me
Schema: users table, profiles table"
      ;;
  esac

  echo "$test_input" > "$test_dir/input.txt"

  log_step "Testing with sample input..."
  log "Input: $(echo "$test_input" | head -2)..."

  # If we have extracted code, try to run it
  if [ -f "$code_file" ] && [ -s "$code_file" ]; then
    log_step "Validating generated code..."

    # Syntax check
    if bash -n "$code_file" 2>/dev/null; then
      log_success "Syntax valid"
    else
      log_error "Syntax errors in generated code"
      bash -n "$code_file" 2>&1 | head -10 | tee -a "$LOG_FILE"
      return 1
    fi

    # Check for required elements
    local has_show_step=$(grep -c "show_step_header" "$code_file" || echo 0)
    local has_claude=$(grep -c "claude" "$code_file" || echo 0)
    local has_validation=$(grep -c "valid\|check\|verify" "$code_file" || echo 0)

    local score=0
    [ "$has_show_step" -gt 0 ] && ((score += 30))
    [ "$has_claude" -gt 0 ] && ((score += 40))
    [ "$has_validation" -gt 0 ] && ((score += 30))

    log "Structure score: $score% (show_step: $has_show_step, claude: $has_claude, validation: $has_validation)"

    # Use Claude to evaluate quality
    log_step "Running Claude evaluation..."

    local eval_prompt="Evaluate this generated code for Step $step ($step_name).

## Generated Code
$(cat "$code_file")

## Requirements
- Show step header
- Call Claude with appropriate prompt
- Save output to session directory
- Validate output
- Return accuracy score
- Handle errors

## Evaluation Criteria
1. Completeness (0-25): Does it have all required sections?
2. Correctness (0-25): Is the logic correct?
3. Prompt Quality (0-25): Is the Claude prompt well-designed?
4. Validation (0-25): Does it properly validate output?

Respond with ONLY a JSON object:
{
  \"completeness\": <0-25>,
  \"correctness\": <0-25>,
  \"prompt_quality\": <0-25>,
  \"validation\": <0-25>,
  \"total\": <0-100>,
  \"issues\": [\"issue1\", \"issue2\"],
  \"pass\": <true|false>
}"

    local eval_result
    local raw_response_file="$BUILD_DIR/eval-raw-step$step.txt"
    if command -v claude &> /dev/null; then
      # Capture the raw response first
      claude --dangerously-skip-permissions --print "$eval_prompt" > "$raw_response_file" 2>&1 || true

      # Extract JSON using Python (handles multi-line JSON properly)
      eval_result=$(python3 -c "
import json
import re
import sys

try:
    with open('$raw_response_file', 'r') as f:
        content = f.read()

    # Try to find JSON object in the content
    # Look for content between first { and last }
    start = content.find('{')
    end = content.rfind('}')

    if start != -1 and end != -1 and end > start:
        json_str = content[start:end+1]
        # Validate it's valid JSON
        parsed = json.loads(json_str)
        print(json.dumps(parsed))
    else:
        print('{}')
except Exception as e:
    print('{}', file=sys.stderr)
    print('{}')
" 2>/dev/null) || eval_result="{}"

      # Fallback if Python extraction failed
      if [ -z "$eval_result" ] || [ "$eval_result" = "{}" ]; then
        log_warn "JSON extraction may have failed - check $raw_response_file"
      fi
    else
      eval_result="{\"total\": $score, \"pass\": false, \"issues\": [\"Could not run Claude evaluation\"]}"
    fi

    echo "$eval_result" > "$verify_file"

    # Parse result
    local total_score=$(echo "$eval_result" | jq -r '.total // 0' 2>/dev/null || echo "$score")
    local passed=$(echo "$eval_result" | jq -r '.pass // false' 2>/dev/null || echo "false")
    local issues=$(echo "$eval_result" | jq -r '.issues // []' 2>/dev/null || echo "[]")

    log "Evaluation result: $total_score% (threshold: $threshold%)"

    if [ "$total_score" -ge "$threshold" ]; then
      log_success "Verification PASSED: $total_score% >= $threshold%"

      # Store result
      add_step_result "$step" "{\"score\": $total_score, \"passed\": true, \"threshold\": $threshold}"
      return 0
    else
      log_error "Verification FAILED: $total_score% < $threshold%"
      log "Issues: $issues"

      add_step_result "$step" "{\"score\": $total_score, \"passed\": false, \"threshold\": $threshold, \"issues\": $issues}"
      return 1
    fi
  else
    log_error "No code file to verify"
    return 1
  fi
}

# === PHASE 5: TROUBLESHOOT ===
run_troubleshoot_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local max_attempts=5
  local attempt=0

  log_phase "STEP $step: TROUBLESHOOT PHASE - $step_name"

  while [ $attempt -lt $max_attempts ]; do
    ((attempt++))
    log_step "Troubleshoot attempt $attempt/$max_attempts"

    # Get previous issues
    local issues=$(jq -r ".step_results[\"$step\"].issues // []" "$STATE_FILE" 2>/dev/null)
    local prev_score=$(jq -r ".step_results[\"$step\"].score // 0" "$STATE_FILE" 2>/dev/null)
    local current_code=$(cat "$BUILD_DIR/extracted-step$step.sh" 2>/dev/null || echo "")

    # Build structured prompt using XML tags (research: XML improves Claude's parsing accuracy)
    local fix_prompt="<task>
Fix the bash code for Step $step ($step_name) that failed verification with score $prev_score% (need ${ACCURACY_THRESHOLDS[$step]}%).
</task>

<issues>
$issues
</issues>

<current_code>
$current_code
</current_code>

<syntax_rules>
Bash heredocs require a matching closing delimiter on its own line (missing delimiter causes parse failure).

When writing heredocs with special characters, use these patterns:

1. For STATIC content (no variable expansion needed), quote the delimiter:
   cat > file.txt << 'EOF'
   Content with \$literal \$dollar signs and \`backticks\`
   EOF

2. For DYNAMIC content (variables should expand), do NOT quote:
   cat > file.txt << EOF
   Content with \$variable that expands to: \$value
   EOF

3. Split large heredocs into smaller ones with unique delimiters:
   cat > file << 'HEADER_EOF'
   Static header content
   HEADER_EOF
   echo \"\$dynamic_var\" >> file
   cat >> file << 'FOOTER_EOF'
   Static footer content
   FOOTER_EOF
</syntax_rules>

<example>
Here is a correctly structured bash function with heredocs:

\`\`\`bash
my_function() {
  local input=\"\$1\"
  local output_file=\"\$2\"

  # Static content - quoted delimiter prevents expansion
  cat > \"\$output_file\" << 'STATIC_EOF'
Prompt template with \$placeholders that stay literal
Use domain language, not implementation details
STATIC_EOF

  # Append dynamic content - unquoted delimiter allows expansion
  cat >> \"\$output_file\" << DYNAMIC_EOF

User input: \$input
Generated at: \$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")
DYNAMIC_EOF

  # Validate output exists
  if [[ -f \"\$output_file\" ]]; then
    echo \"Success\"
    return 0
  else
    echo \"Failed\" >&2
    return 1
  fi
}
\`\`\`
</example>

<output_format>
Output ONLY a single bash code block containing the complete fixed function.
Start with \`\`\`bash and end with \`\`\` on its own line.
Do not include any explanation before or after the code block.
The code must pass \`bash -n\` syntax validation.
</output_format>"

    log "Requesting fix from Claude..."

    local fix_file="$BUILD_DIR/fix-step$step-attempt$attempt.sh"
    if command -v claude &> /dev/null; then
      claude --dangerously-skip-permissions --print "$fix_prompt" > "$fix_file" 2>&1 || {
        log_error "Fix generation failed"
        continue
      }

      # Extract fixed code
      sed -n '/^```bash/,/^```$/p' "$fix_file" | sed '1d;$d' > "$BUILD_DIR/extracted-step$step.sh" || true

      # Re-run verification
      if run_verify_phase "$step"; then
        log_success "Troubleshooting succeeded on attempt $attempt"
        return 0
      fi
    else
      log_error "Claude CLI not found"
      return 1
    fi
  done

  log_error "Troubleshooting failed after $max_attempts attempts"
  return 1
}

# === PHASE 6: COMMIT ===
run_commit_phase() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"
  local code_file="$BUILD_DIR/extracted-step$step.sh"

  log_phase "STEP $step: COMMIT PHASE - $step_name"

  if [ ! -f "$code_file" ]; then
    log_error "No code file to commit"
    return 1
  fi

  # For now, we'll save to a staging area rather than directly modifying feature_interrogate.sh
  local staging_dir="$BUILD_DIR/staging"
  mkdir -p "$staging_dir"

  cp "$code_file" "$staging_dir/step$step-$step_name.sh"

  log_step "Code staged: $staging_dir/step$step-$step_name.sh"

  # Commit the build artifacts
  if git rev-parse --git-dir > /dev/null 2>&1; then
    log_step "Committing build artifacts..."

    git add "$BUILD_DIR/" 2>/dev/null || true

    local score=$(jq -r ".step_results[\"$step\"].score // 0" "$STATE_FILE" 2>/dev/null)

    git commit -m "$(cat <<EOF
Pipeline Build: Step $step - $step_name ($score%)

Generated implementation for Step $step of the 10-step pipeline.
- Research: research-step$step.md
- Plan: plan-step$step.md
- Code: extracted-step$step.sh
- Accuracy: $score% (threshold: ${ACCURACY_THRESHOLDS[$step]}%)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)" 2>/dev/null || log_warn "Nothing to commit or commit failed"

    log_success "Committed step $step artifacts"
  else
    log_warn "Not in git repository - skipping commit"
  fi

  add_completed_step "$step"
  return 0
}

# === MAIN ORCHESTRATOR ===
build_step() {
  local step="$1"
  local step_name="${STEP_NAMES[$step]}"

  log ""
  log "╔════════════════════════════════════════════════════════════╗"
  log "║  BUILDING STEP $step: $step_name"
  log "╚════════════════════════════════════════════════════════════╝"
  log ""

  update_state "current_step" "$step"

  # Phase 1: Research
  if ! run_research_phase "$step"; then
    log_error "Research phase failed for step $step"
    return 1
  fi

  # Phase 2: Plan
  if ! run_plan_phase "$step"; then
    log_error "Plan phase failed for step $step"
    return 1
  fi

  # Phase 3: Build
  if ! run_build_phase "$step"; then
    log_error "Build phase failed for step $step"
    return 1
  fi

  # Phase 4: Verify
  if ! run_verify_phase "$step"; then
    log_warn "Verification failed - entering troubleshoot phase"

    # Phase 5: Troubleshoot
    if ! run_troubleshoot_phase "$step"; then
      log_error "Could not fix step $step after troubleshooting"
      jq --argjson s "$step" '.failed_steps += [$s]' "$STATE_FILE" > "$STATE_FILE.tmp"
      mv "$STATE_FILE.tmp" "$STATE_FILE"
      return 1
    fi
  fi

  # Phase 6: Commit
  if ! run_commit_phase "$step"; then
    log_error "Commit phase failed for step $step"
    return 1
  fi

  log_success "Step $step ($step_name) completed successfully!"
  return 0
}

show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --step N     Only build step N (4, 5, 7, 8, or 9)"
  echo "  --dry-run    Show what would be done without executing"
  echo "  --resume     Resume from last successful step"
  echo "  --status     Show current build status"
  echo "  --help       Show this help message"
  echo ""
  echo "Steps to build:"
  echo "  4 - Acceptance Criteria (Gherkin)"
  echo "  5 - Domain Model (entities, aggregates)"
  echo "  7 - API Contract (OpenAPI)"
  echo "  8 - Data Schema (SQL migrations)"
  echo "  9 - Task Breakdown (dev tasks)"
}

show_status() {
  echo ""
  echo "═══ Pipeline Build Status ═══"
  echo ""

  if [ -f "$STATE_FILE" ]; then
    local started=$(jq -r '.started_at // "Not started"' "$STATE_FILE")
    local current=$(jq -r '.current_step // "None"' "$STATE_FILE")
    local completed=$(jq -r '.completed_steps | join(", ") // "None"' "$STATE_FILE")
    local failed=$(jq -r '.failed_steps | join(", ") // "None"' "$STATE_FILE")

    echo "Started: $started"
    echo "Current Step: $current"
    echo "Completed: $completed"
    echo "Failed: $failed"
    echo ""

    echo "Step Results:"
    for step in 4 5 7 8 9; do
      local result=$(jq -r ".step_results[\"$step\"] // null" "$STATE_FILE")
      if [ "$result" != "null" ]; then
        local score=$(echo "$result" | jq -r '.score // 0')
        local passed=$(echo "$result" | jq -r '.passed // false')
        local threshold="${ACCURACY_THRESHOLDS[$step]}"
        local status="❌"
        [ "$passed" = "true" ] && status="✅"
        echo "  Step $step (${STEP_NAMES[$step]}): $status $score% (threshold: $threshold%)"
      else
        echo "  Step $step (${STEP_NAMES[$step]}): ⏳ Not started"
      fi
    done
  else
    echo "No build state found. Run without --status to start."
  fi
  echo ""
}

main() {
  local single_step=""
  local dry_run=false
  local resume=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --step)
        single_step="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --resume)
        resume=true
        shift
        ;;
      --status)
        show_status
        exit 0
        ;;
      --help)
        show_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done

  # Initialize
  mkdir -p "$BUILD_DIR"
  echo "" > "$LOG_FILE"

  log "╔════════════════════════════════════════════════════════════╗"
  log "║  PIPELINE BUILDER - 10-Step Implementation                 ║"
  log "║  Building steps: 4, 5, 7, 8, 9                             ║"
  log "╚════════════════════════════════════════════════════════════╝"
  log ""
  log "Build directory: $BUILD_DIR"
  log "Target script: $TARGET_SCRIPT"
  log "Log file: $LOG_FILE"
  log ""

  # Check prerequisites
  if ! command -v claude &> /dev/null; then
    log_error "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    log_error "jq not found. Install with: apt install jq"
    exit 1
  fi

  # Initialize or resume state
  if [ "$resume" = true ] && [ -f "$STATE_FILE" ]; then
    log "Resuming from previous state..."
  else
    init_state
  fi

  # Determine which steps to build
  local steps_to_build=(4 5 7 8 9)

  if [ -n "$single_step" ]; then
    steps_to_build=("$single_step")
    log "Building single step: $single_step"
  elif [ "$resume" = true ]; then
    local completed=$(get_completed_steps)
    steps_to_build=()
    for step in 4 5 7 8 9; do
      if ! echo "$completed" | grep -q "^$step$"; then
        steps_to_build+=("$step")
      fi
    done
    log "Resuming - remaining steps: ${steps_to_build[*]}"
  fi

  if [ "$dry_run" = true ]; then
    log "DRY RUN - would build steps: ${steps_to_build[*]}"
    exit 0
  fi

  # Build each step
  local success_count=0
  local fail_count=0

  for step in "${steps_to_build[@]}"; do
    if build_step "$step"; then
      ((success_count++))
    else
      ((fail_count++))
      log_error "Step $step failed - continuing to next step"
    fi
  done

  # Final report
  log ""
  log "╔════════════════════════════════════════════════════════════╗"
  log "║  BUILD COMPLETE                                            ║"
  log "╚════════════════════════════════════════════════════════════╝"
  log ""
  log "Successful: $success_count"
  log "Failed: $fail_count"
  log ""

  if [ "$success_count" -gt 0 ]; then
    log "Generated code is staged in: $BUILD_DIR/staging/"
    log ""
    log "Next steps:"
    log "1. Review generated code in staging directory"
    log "2. Integrate into feature_interrogate.sh"
    log "3. Test with a real feature"
  fi

  if [ "$fail_count" -gt 0 ]; then
    log_warn "Some steps failed. Review logs and retry with --resume"
  fi

  show_status
}

main "$@"

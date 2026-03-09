---
allowed-tools: Bash, Read, Write, LS, Grep, Task, AskUserQuestion
---

# Troubleshoot - Hypothesis-Driven Issue Diagnosis

Interactively diagnose issues through structured hypothesis testing, then generate and execute an autonomous feedback loop that learns from each iteration.

## Research Foundation

This skill implements findings from research on effective LLM troubleshooting loops:
- **Hypothesis-driven diagnosis** (not pattern matching)
- **Structured state tracking** (hypotheses, attempts, learnings persist)
- **Anti-repetition mechanisms** (block repeated ineffective fixes)
- **Structured post-mortems** (extract learning from each failure)
- **External termination enforcement** (script decides when to stop, not Claude)
- **Multi-perspective analysis** (break confirmation bias when stuck)

## Usage
```
/pm:troubleshoot [issue-name]
```

## Arguments
- `issue-name` (optional): Name for this troubleshooting session. Defaults to timestamp.

## Output
- `.claude/troubleshoot/{issue-name}/session.md` - Full session record
- `.claude/troubleshoot/{issue-name}/state.json` - Structured state (hypotheses, attempts, learnings)
- `.claude/troubleshoot/{issue-name}/troubleshoot-{issue-name}.sh` - Generated feedback loop script
- `.claude/troubleshoot/{issue-name}/troubleshoot.log` - Execution log

---

## Instructions

### Step 1: Initialize Session

Get current datetime and set up session directory:

```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ISSUE_NAME="${ARGUMENTS:-$(date +%Y%m%d-%H%M%S)}"
SESSION_DIR=".claude/troubleshoot/$ISSUE_NAME"
mkdir -p "$SESSION_DIR"
```

Create initial session.md:
```markdown
# Troubleshooting Session: {issue-name}

Started: {CURRENT_DATE}
Status: gathering-info

---

## Problem Statement
{to be filled from user answers}
```

### Step 2: Gather Information (Interactive Questions)

Use AskUserQuestion to gather essential information. Ask ONE question at a time.

**Q1: Target Script**
```
question: "What script or command is causing issues?"
header: "Target"
options:
  - label: "I'll paste the path"
    description: "You'll provide the exact file path"
  - label: "I'll describe it"
    description: "You'll describe what the script does"
```

**Q2: Problem Type**
```
question: "What type of problem are you experiencing?"
header: "Problem"
options:
  - label: "Inconsistent results"
    description: "Different results between runs"
  - label: "Wrong output"
    description: "Consistent but incorrect output"
  - label: "Missing elements"
    description: "Required elements not appearing"
  - label: "Can't parse output"
    description: "Unable to extract/parse results"
```

**Q3: Success Criteria**
```
question: "How will you know when it's fixed?"
header: "Success"
options:
  - label: "Consistent output"
    description: "Same output across multiple runs"
  - label: "Specific elements present"
    description: "Certain elements must appear"
  - label: "Match a reference"
    description: "Output must match expected format"
  - label: "Pass validation"
    description: "Must pass a validation check"
```

Record answers to session.md and proceed.

### Step 3: Read Target Script

If a target script path was provided, read it:
```bash
head -300 "$TARGET_SCRIPT"
```

### Step 4: Generate Initial Hypotheses

Based on the problem type and script content, generate 3-5 initial hypotheses ranked by likelihood. This happens in the generated script, not here.

### Step 5: Generate Feedback Loop Script

Generate a script that implements the full analyze-decide-act loop with state management.

```bash
SCRIPT_FILE="$SESSION_DIR/troubleshoot-$ISSUE_NAME.sh"
```

---

## Core Loop Architecture

The generated script implements this loop (research-backed):

```
while (SYSTEM checks termination - not agent):
    1. ANALYZE    → Examine output, update hypotheses
    2. DECIDE     → Choose action (with repetition check)
    3. ACT        → Execute fix
    4. REFLECT    → Structured post-mortem
    5. PERSIST    → Update state with learning
```

**Critical:** The SYSTEM (script) enforces termination. Claude never decides "I should stop."

---

## State Schema

Every generated script MUST maintain this state in `state.json`:

```json
{
  "session_id": "{issue-name}",
  "started_at": "{ISO datetime}",
  "current_iteration": 0,
  "original_problem": "{description}",
  "current_symptom": "{latest observation}",
  "goal_state": "{success criteria}",

  "hypotheses": [
    {
      "id": "H1",
      "description": "what might be causing this",
      "confidence": 70,
      "status": "ACTIVE",
      "evidence_for": [],
      "evidence_against": [],
      "tests_performed": []
    }
  ],

  "attempted_fixes": [
    {
      "iteration": 1,
      "hypothesis_tested": "H1",
      "action_taken": "what we did",
      "expected_outcome": "what we thought would happen",
      "actual_outcome": "what actually happened",
      "conclusion": "WORKED|PARTIAL|FAILED|INCONCLUSIVE",
      "learning": "why it did or didn't work"
    }
  ],

  "termination": {
    "max_iterations": 20,
    "max_time_seconds": 600,
    "repetition_threshold": 7,
    "progress_window": 3
  }
}
```

---

## Termination Criteria (External Enforcement)

The script (NOT Claude) enforces these termination conditions:

```bash
check_termination() {
  local state_file="$1"

  # Hard limits
  local iteration=$(jq -r '.current_iteration' "$state_file")
  local max_iter=$(jq -r '.termination.max_iterations' "$state_file")
  if [ "$iteration" -ge "$max_iter" ]; then
    echo "MAX_ITERATIONS_REACHED"
    return 0
  fi

  # Success condition - check if goal achieved
  if [ -f "$SESSION_DIR/success_flag" ]; then
    echo "SUCCESS"
    return 0
  fi

  # Stuck detection - same action repeated N times
  local last_actions=$(jq -r '[.attempted_fixes[-3:][].action_taken] | unique | length' "$state_file")
  if [ "$last_actions" -eq 1 ] && [ "$(jq '.attempted_fixes | length' "$state_file")" -ge 3 ]; then
    echo "STUCK_REPEATING"
    return 0
  fi

  # All hypotheses exhausted
  local active=$(jq '[.hypotheses[] | select(.status == "ACTIVE")] | length' "$state_file")
  if [ "$active" -eq 0 ]; then
    echo "ALL_HYPOTHESES_EXHAUSTED"
    return 0
  fi

  echo "CONTINUE"
  return 1
}
```

---

## Anti-Repetition Check

Before applying any fix, check it hasn't been tried before:

```bash
check_not_repeating() {
  local proposed_fix="$1"
  local state_file="$2"

  # Get fingerprint of proposed fix (first 100 chars, normalized)
  local fingerprint=$(echo "$proposed_fix" | head -c 100 | tr -s '[:space:]' ' ')

  # Check against previous attempts
  local similar=$(jq -r --arg fp "$fingerprint" '
    .attempted_fixes[] |
    select(.conclusion == "FAILED" or .conclusion == "INCONCLUSIVE") |
    select(.action_taken | startswith($fp[0:50]))
  ' "$state_file")

  if [ -n "$similar" ]; then
    echo "BLOCKED: Similar to previous failed attempt"
    return 1
  fi

  return 0
}
```

---

## Prompt Templates

### Initial Diagnostic Prompt

```bash
claude --dangerously-skip-permissions --print "$(cat <<'DIAGNOSIS_EOF'
<role>
You are a systematic troubleshooter using hypothesis-driven diagnosis.
Your task is to diagnose and fix the following problem.
</role>

<problem>
$ORIGINAL_PROBLEM
</problem>

<current_observation>
$CURRENT_SYMPTOM
</current_observation>

<current_state>
$(cat "$STATE_FILE")
</current_state>

<instructions>
1. Review the current hypotheses and their confidence levels
2. Based on the observation, UPDATE hypothesis confidences (Bayesian update)
3. Select the MOST INFORMATIVE action (not necessarily the most likely fix)
4. Provide your analysis in the exact format below
</instructions>

<output_format>
### Hypothesis Updates
H1: [confidence change] because [reason]
H2: [confidence change] because [reason]

### Selected Action
ACTION_TYPE: DIAGNOSTIC | FIX
TARGET_HYPOTHESIS: H[n]
DESCRIPTION: [what to do]
EXPECTED_IF_CORRECT: [outcome if hypothesis is right]
EXPECTED_IF_WRONG: [outcome if hypothesis is wrong]

### Fix Details (if ACTION_TYPE is FIX)
FILE: [path]
OLD_STRING: |
  [exact text to find]
NEW_STRING: |
  [replacement text]
</output_format>

<constraints>
- Skip actions already in attempted_fixes with FAILED status
- Prefer DIAGNOSTIC actions until confidence > 70%
- Each action must have clear expected outcomes for both success and failure
- OLD_STRING must match exactly what exists in the file
</constraints>
DIAGNOSIS_EOF
)"
```

### Reflection/Post-Mortem Prompt

```bash
claude --dangerously-skip-permissions --print "$(cat <<'REFLECTION_EOF'
<role>
You are analyzing a troubleshooting attempt to extract maximum learning.
</role>

<action_taken>
$ACTION_DESCRIPTION
</action_taken>

<expected_outcome>
$EXPECTED_OUTCOME
</expected_outcome>

<actual_outcome>
$ACTUAL_OUTCOME
</actual_outcome>

<current_state>
$(cat "$STATE_FILE")
</current_state>

<instructions>
Analyze this result and extract learning. Answer these questions:
1. Did the action succeed, partially succeed, or fail?
2. If it failed, WHY? (hypothesis wrong vs implementation wrong vs unexpected factor)
3. What NEW INFORMATION did we gain?
4. How should this UPDATE our hypotheses?
5. What should we try DIFFERENTLY next time?
</instructions>

<output_format>
### Conclusion
RESULT: WORKED | PARTIAL | FAILED | INCONCLUSIVE

### Analysis
[Why did we get this result?]

### New Information
[What do we now know that we didn't before?]

### Hypothesis Updates
H1: [CONFIRMED|REFUTED|STRENGTHENED|WEAKENED|UNCHANGED] - [reason]

### Key Learning
[Single most important takeaway]

### Next Direction
[Based on this learning, what's the best next move?]
</output_format>
REFLECTION_EOF
)"
```

### Novel Approach Prompt (When Repetition Detected)

```bash
claude --dangerously-skip-permissions --print "$(cat <<'NOVEL_EOF'
<role>
Your proposed action was blocked because it's too similar to a previous failed attempt.
Generate a genuinely different approach.
</role>

<blocked_reason>
$BLOCKED_REASON
</blocked_reason>

<previous_attempts>
$(jq '.attempted_fixes[] | select(.conclusion == "FAILED")' "$STATE_FILE")
</previous_attempts>

<current_hypotheses>
$(jq '.hypotheses' "$STATE_FILE")
</current_hypotheses>

<instructions>
Generate a genuinely novel approach. Consider:
1. A completely different hypothesis
2. A different diagnostic angle
3. A different fix mechanism (even if same hypothesis)
4. Escalation: gather more information before any more fixes
</instructions>

<alternative_angles>
- Have we verified basic assumptions?
- Have we checked the simplest possible causes?
- Have we looked at environment/context?
- Have we considered timing/race conditions?
- Have we checked dependencies/versions?
</alternative_angles>

<output_format>
### Novel Approach
[Describe genuinely different action]

### Why This Is Different
[Explain how this differs from previous attempts]

### Fix Details (if applicable)
FILE: [path]
OLD_STRING: |
  [exact text]
NEW_STRING: |
  [replacement]
</output_format>
NOVEL_EOF
)"
```

### Multi-Perspective Analysis (When Stuck)

When the same fix is attempted 3+ times, use multi-perspective analysis:

```bash
claude --dangerously-skip-permissions --print "$(cat <<'MULTIPERSPECTIVE_EOF'
<role>
The troubleshooting loop is stuck. Analyze from multiple perspectives to find a breakthrough.
</role>

<problem>
$ORIGINAL_PROBLEM
</problem>

<attempts_so_far>
$(jq '.attempted_fixes' "$STATE_FILE")
</attempts_so_far>

<instructions>
Analyze this problem from THREE different expert perspectives.
Each perspective should identify what the others might be missing.
</instructions>

<perspectives>
### Senior Engineer Perspective
"Looking at this systematically, the pattern I see is..."
"The root cause is likely..."
"We should try..."

### QA Engineer Perspective
"The edge case that might be causing this is..."
"We haven't tested..."
"The assumption that might be wrong is..."

### Skeptic Perspective
"Everyone is assuming X, but what if..."
"The obvious solution hasn't worked because..."
"A completely different explanation is..."

### Synthesis
Considering all perspectives, the most promising NEW direction is:
[Concrete next action that differs from all previous attempts]
</perspectives>
</output_format>
MULTIPERSPECTIVE_EOF
)"
```

---

## Generated Script Template

```bash
#!/bin/bash
# troubleshoot-{issue-name}.sh
# Generated by /pm:troubleshoot on {CURRENT_DATE}
#
# Problem: {description}
# Success Criteria: {criteria}
# Research-backed hypothesis-driven troubleshooting loop

set -euo pipefail

# === CONFIGURATION ===
SESSION_DIR="{absolute path to session dir}"
PROJECT_ROOT="{absolute path to project root}"
TARGET_SCRIPT="{absolute path to target script}"
STATE_FILE="$SESSION_DIR/state.json"
LOG_FILE="$SESSION_DIR/troubleshoot.log"

# === LOGGING ===
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
log_success() { echo "[$(date +%H:%M:%S)] ✅ $*" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date +%H:%M:%S)] ❌ $*" | tee -a "$LOG_FILE"; }
log_warn() { echo "[$(date +%H:%M:%S)] ⚠️  $*" | tee -a "$LOG_FILE"; }

# === STATE MANAGEMENT ===
init_state() {
  cat > "$STATE_FILE" << 'STATE_EOF'
{
  "session_id": "{issue-name}",
  "started_at": "{CURRENT_DATE}",
  "current_iteration": 0,
  "original_problem": "{problem description}",
  "current_symptom": "",
  "goal_state": "{success criteria}",
  "hypotheses": [
    {
      "id": "H1",
      "description": "{initial hypothesis 1}",
      "confidence": 50,
      "status": "ACTIVE",
      "evidence_for": [],
      "evidence_against": [],
      "tests_performed": []
    },
    {
      "id": "H2",
      "description": "{initial hypothesis 2}",
      "confidence": 30,
      "status": "ACTIVE",
      "evidence_for": [],
      "evidence_against": [],
      "tests_performed": []
    },
    {
      "id": "H3",
      "description": "{initial hypothesis 3}",
      "confidence": 20,
      "status": "ACTIVE",
      "evidence_for": [],
      "evidence_against": [],
      "tests_performed": []
    }
  ],
  "attempted_fixes": [],
  "termination": {
    "max_iterations": 20,
    "max_time_seconds": 600,
    "repetition_threshold": 7,
    "progress_window": 3
  }
}
STATE_EOF
}

update_iteration() {
  local new_iter=$1
  jq --argjson iter "$new_iter" '.current_iteration = $iter' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

update_symptom() {
  local symptom="$1"
  jq --arg sym "$symptom" '.current_symptom = $sym' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

add_attempt() {
  local iteration=$1
  local hypothesis=$2
  local action=$3
  local expected=$4
  local actual=$5
  local conclusion=$6
  local learning=$7

  jq --argjson iter "$iteration" \
     --arg hyp "$hypothesis" \
     --arg act "$action" \
     --arg exp "$expected" \
     --arg actual "$actual" \
     --arg conc "$conclusion" \
     --arg learn "$learning" \
     '.attempted_fixes += [{
       "iteration": $iter,
       "hypothesis_tested": $hyp,
       "action_taken": $act,
       "expected_outcome": $exp,
       "actual_outcome": $actual,
       "conclusion": $conc,
       "learning": $learn
     }]' "$STATE_FILE" > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# === TERMINATION CHECK ===
check_termination() {
  local iteration=$(jq -r '.current_iteration' "$STATE_FILE")
  local max_iter=$(jq -r '.termination.max_iterations' "$STATE_FILE")

  # Hard limit
  if [ "$iteration" -ge "$max_iter" ]; then
    echo "MAX_ITERATIONS_REACHED"
    return 0
  fi

  # Success flag
  if [ -f "$SESSION_DIR/success_flag" ]; then
    echo "SUCCESS"
    return 0
  fi

  # Stuck detection
  local num_attempts=$(jq '.attempted_fixes | length' "$STATE_FILE")
  if [ "$num_attempts" -ge 3 ]; then
    local unique_actions=$(jq '[.attempted_fixes[-3:][].action_taken] | unique | length' "$STATE_FILE")
    if [ "$unique_actions" -eq 1 ]; then
      echo "STUCK_REPEATING"
      return 0
    fi
  fi

  # All hypotheses exhausted
  local active=$(jq '[.hypotheses[] | select(.status == "ACTIVE")] | length' "$STATE_FILE")
  if [ "$active" -eq 0 ]; then
    echo "ALL_HYPOTHESES_EXHAUSTED"
    return 0
  fi

  echo "CONTINUE"
  return 1
}

# === ANTI-REPETITION CHECK ===
check_not_repeating() {
  local proposed_fix="$1"
  local fingerprint=$(echo "$proposed_fix" | head -c 100 | tr -s '[:space:]' ' ')

  # Check against failed attempts
  local failed_actions=$(jq -r '.attempted_fixes[] | select(.conclusion == "FAILED" or .conclusion == "INCONCLUSIVE") | .action_taken' "$STATE_FILE")

  while IFS= read -r past_action; do
    if [ -z "$past_action" ]; then continue; fi
    local past_fp=$(echo "$past_action" | head -c 100 | tr -s '[:space:]' ' ')
    if [ "$fingerprint" = "$past_fp" ]; then
      log_warn "BLOCKED: Similar to previous failed attempt"
      return 1
    fi
  done <<< "$failed_actions"

  return 0
}

# === APPLY FIX FUNCTION ===
apply_fix() {
  local fix_file="$1"

  if [ ! -f "$fix_file" ]; then
    log_error "Fix file not found: $fix_file"
    return 1
  fi

  log "Parsing fix from: $fix_file"

  local target_file=""
  local old_string=""
  local new_string=""
  local in_old=false
  local in_new=false

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^FILE:[[:space:]]*(.*) ]]; then
      target_file="${BASH_REMATCH[1]}"
      target_file=$(echo "$target_file" | xargs)
      in_old=false
      in_new=false
      continue
    fi

    if [[ "$line" =~ ^OLD_STRING:[[:space:]]*\|?$ ]] || [[ "$line" =~ ^OLD_STRING:[[:space:]]+(.*) ]]; then
      in_old=true
      in_new=false
      old_string=""
      if [[ "${BASH_REMATCH[1]:-}" != "" ]] && [[ ! "${BASH_REMATCH[1]}" =~ ^\|$ ]]; then
        old_string="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if [[ "$line" =~ ^NEW_STRING:[[:space:]]*\|?$ ]] || [[ "$line" =~ ^NEW_STRING:[[:space:]]+(.*) ]]; then
      in_new=true
      in_old=false
      new_string=""
      if [[ "${BASH_REMATCH[1]:-}" != "" ]] && [[ ! "${BASH_REMATCH[1]}" =~ ^\|$ ]]; then
        new_string="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if $in_old; then
      if [[ "$line" =~ ^(NEW_STRING:|FILE:) ]]; then
        in_old=false
        if [[ "$line" =~ ^NEW_STRING: ]]; then
          in_new=true
          new_string=""
        fi
        continue
      fi
      local cleaned_line="${line#  }"
      if [ -z "$old_string" ]; then
        old_string="$cleaned_line"
      else
        old_string="$old_string"$'\n'"$cleaned_line"
      fi
    elif $in_new; then
      if [[ "$line" =~ ^(FILE:|OLD_STRING:) ]]; then
        in_new=false
        if [ -n "$target_file" ] && [ -n "$old_string" ]; then
          _do_apply_fix "$target_file" "$old_string" "$new_string"
        fi
        if [[ "$line" =~ ^FILE: ]]; then
          target_file="${line#FILE: }"
          target_file=$(echo "$target_file" | xargs)
        fi
        old_string=""
        new_string=""
        continue
      fi
      local cleaned_line="${line#  }"
      if [ -z "$new_string" ]; then
        new_string="$cleaned_line"
      else
        new_string="$new_string"$'\n'"$cleaned_line"
      fi
    fi
  done < "$fix_file"

  if [ -n "$target_file" ] && [ -n "$old_string" ]; then
    _do_apply_fix "$target_file" "$old_string" "$new_string"
  fi
}

_do_apply_fix() {
  local target_file="$1"
  local old_string="$2"
  local new_string="$3"

  # Resolve path
  if [[ ! "$target_file" = /* ]]; then
    if [ -f "$PROJECT_ROOT/$target_file" ]; then
      target_file="$PROJECT_ROOT/$target_file"
    elif [ -f "$target_file" ]; then
      target_file="$(pwd)/$target_file"
    fi
  fi

  if [ ! -f "$target_file" ]; then
    log_warn "Target file not found: $target_file, using TARGET_SCRIPT"
    target_file="$TARGET_SCRIPT"
  fi

  if [ ! -f "$target_file" ]; then
    log_error "Cannot find target file for fix"
    return 1
  fi

  # Create backup
  local backup_file="$target_file.backup-$(date +%s)"
  cp "$target_file" "$backup_file"
  log "Backup: $backup_file"

  # Apply fix with Python
  python3 << PYTHON_EOF
import sys

target_file = '''$target_file'''
old_string = '''$old_string'''
new_string = '''$new_string'''

try:
    with open(target_file, 'r') as f:
        content = f.read()

    if old_string in content:
        new_content = content.replace(old_string, new_string, 1)
        with open(target_file, 'w') as f:
            f.write(new_content)
        print(f"SUCCESS: Applied fix to {target_file}")
        sys.exit(0)
    else:
        import re
        old_pattern = re.escape(old_string)
        old_pattern = re.sub(r'\\ +', r'\\s+', old_pattern)
        if re.search(old_pattern, content):
            new_content = re.sub(old_pattern, new_string.replace('\\\\', '\\\\\\\\'), content, count=1)
            with open(target_file, 'w') as f:
                f.write(new_content)
            print(f"SUCCESS: Applied fix (whitespace normalized)")
            sys.exit(0)
        print(f"ERROR: Could not find OLD_STRING in {target_file}")
        sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON_EOF

  local result=$?
  if [ $result -eq 0 ]; then
    log_success "Fix applied to $target_file"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) Applied fix to $target_file" >> "$SESSION_DIR/fixes-applied.log"
    return 0
  else
    log_error "Failed to apply fix"
    cp "$backup_file" "$target_file"
    log "Restored from backup"
    return 1
  fi
}

# === SUCCESS CHECK ===
check_success() {
  # {CUSTOMIZE: Add success verification based on problem type}
  # For inconsistency: run twice and compare
  # For accuracy: validate output
  # For coverage: check required elements

  local output1="$SESSION_DIR/check-1.out"
  local output2="$SESSION_DIR/check-2.out"

  bash "$TARGET_SCRIPT" > "$output1" 2>&1 || true
  bash "$TARGET_SCRIPT" > "$output2" 2>&1 || true

  if diff -q "$output1" "$output2" > /dev/null 2>&1; then
    # {CUSTOMIZE: Additional validation here}
    return 0
  fi
  return 1
}

# === DIAGNOSIS PHASE ===
run_diagnosis() {
  local iteration=$1
  local diagnosis_file="$SESSION_DIR/diagnosis-$iteration.txt"
  local fix_file="$SESSION_DIR/fix-$iteration.txt"

  log "Iteration $iteration: Running diagnosis..."

  # Get current symptom
  local symptom_file="$SESSION_DIR/symptom-$iteration.out"
  bash "$TARGET_SCRIPT" > "$symptom_file" 2>&1 || true
  local symptom=$(head -100 "$symptom_file")
  update_symptom "$symptom"

  # Generate diagnosis
  # {INSERT DIAGNOSTIC PROMPT HERE - customized for problem type}

  # Check for repetition
  local proposed_action=$(grep -A5 "Selected Action" "$diagnosis_file" | head -6)
  if ! check_not_repeating "$proposed_action"; then
    log_warn "Repetition detected - requesting novel approach"
    # {INSERT NOVEL APPROACH PROMPT HERE}
  fi

  echo "$diagnosis_file"
}

# === REFLECTION PHASE ===
run_reflection() {
  local iteration=$1
  local action=$2
  local expected=$3
  local actual=$4
  local reflection_file="$SESSION_DIR/reflection-$iteration.txt"

  log "Iteration $iteration: Reflecting on result..."

  # {INSERT REFLECTION PROMPT HERE}

  # Parse reflection and update state
  local conclusion=$(grep "RESULT:" "$reflection_file" | cut -d: -f2 | xargs)
  local learning=$(grep -A3 "Key Learning" "$reflection_file" | tail -2 | head -1)

  add_attempt "$iteration" "H1" "$action" "$expected" "$actual" "$conclusion" "$learning"

  echo "$reflection_file"
}

# === MAIN LOOP ===
main() {
  mkdir -p "$SESSION_DIR"
  echo "" > "$LOG_FILE"

  log "=== Troubleshooting Session: {issue-name} ==="
  log "Target: $TARGET_SCRIPT"
  log "Problem: {problem description}"

  # Initialize state if not exists
  if [ ! -f "$STATE_FILE" ]; then
    init_state
  fi

  local iteration=0

  while true; do
    ((iteration++))
    update_iteration "$iteration"

    log "--- Iteration $iteration ---"

    # 1. CHECK TERMINATION (External enforcement)
    local term_status=$(check_termination)
    case "$term_status" in
      "SUCCESS")
        log_success "Problem fixed!"
        break
        ;;
      "MAX_ITERATIONS_REACHED")
        log_error "Max iterations reached without fix"
        break
        ;;
      "STUCK_REPEATING")
        log_warn "Stuck repeating same action - trying multi-perspective analysis"
        # {INSERT MULTI-PERSPECTIVE PROMPT HERE}
        ;;
      "ALL_HYPOTHESES_EXHAUSTED")
        log_error "All hypotheses exhausted"
        break
        ;;
    esac

    # 2. CHECK SUCCESS
    if check_success; then
      log_success "Success criteria met!"
      touch "$SESSION_DIR/success_flag"
      continue  # Will terminate on next iteration
    fi

    # 3. ANALYZE & DECIDE
    local diagnosis_file=$(run_diagnosis "$iteration")

    # 4. ACT (Apply fix if one was generated)
    local fix_file="$SESSION_DIR/fix-$iteration.txt"
    if [ -f "$fix_file" ]; then
      log "Applying fix..."
      if apply_fix "$fix_file"; then
        log "Fix applied, checking result..."
      else
        log_warn "Fix application failed"
      fi
    fi

    # 5. REFLECT
    local actual_output="$SESSION_DIR/symptom-$iteration.out"
    run_reflection "$iteration" "applied fix" "fixed the issue" "$(head -50 "$actual_output")"

    log "Iteration $iteration complete"
  done

  # === FINAL REPORT ===
  log ""
  log "=== Session Complete ==="
  log "Iterations: $iteration"
  log "Fixes applied: $(wc -l < "$SESSION_DIR/fixes-applied.log" 2>/dev/null || echo 0)"
  log "Final state: $STATE_FILE"

  if [ -f "$SESSION_DIR/success_flag" ]; then
    log_success "RESULT: Fixed"
  else
    log_error "RESULT: Not fixed"
    log "Review state.json for hypotheses and learnings"
  fi

  # === AUTO-COMMIT CHANGES ===
  commit_changes
}

# === AUTO-COMMIT FUNCTION ===
commit_changes() {
  log "Checking for changes to commit..."

  # Check if we're in a git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_warn "Not in a git repository - skipping commit"
    return 0
  fi

  # Check for changes to the target script
  if [ -n "$(git status --porcelain "$TARGET_SCRIPT" 2>/dev/null)" ]; then
    log "Changes detected in $TARGET_SCRIPT"

    # Stage the target script
    git add "$TARGET_SCRIPT"

    # Generate commit message
    local fixes_count=$(wc -l < "$SESSION_DIR/fixes-applied.log" 2>/dev/null || echo 0)
    local iteration=$(jq -r '.current_iteration' "$STATE_FILE" 2>/dev/null || echo "?")
    local result="failed"
    [ -f "$SESSION_DIR/success_flag" ] && result="fixed"

    local commit_msg="Troubleshoot: $result after $iteration iterations ($fixes_count fixes)

Session: $SESSION_DIR
Target: $TARGET_SCRIPT

Hypotheses tested:
$(jq -r '.hypotheses[] | "- \(.id): \(.description) [\(.status)]"' "$STATE_FILE" 2>/dev/null || echo "- Unable to parse hypotheses")

Key learnings:
$(jq -r '.attempted_fixes[-3:][] | "- \(.learning)"' "$STATE_FILE" 2>/dev/null | head -5 || echo "- Unable to parse learnings")

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

    # Commit with the message
    if git commit -m "$commit_msg" 2>&1 | tee -a "$LOG_FILE"; then
      log_success "Changes committed successfully"
    else
      log_warn "Commit failed or nothing to commit"
    fi
  else
    log "No changes to commit for $TARGET_SCRIPT"
  fi
}

main "$@"
```

---

## Step 6: Customize and Write Script

After selecting the template:

1. **Replace placeholders** with actual values
2. **Customize initial hypotheses** based on problem type:
   - Inconsistency: timing, randomness, ordering, race conditions
   - Inaccuracy: logic errors, wrong assumptions, incorrect parsing
   - Coverage gaps: missing cases, incomplete iteration, early termination
   - Parsing: format mismatch, delimiter issues, encoding

3. **Customize success check** based on criteria:
   - Consistent output: run twice, compare
   - Elements present: grep for required patterns
   - Match reference: diff against known good output

4. **Write the script**:
   ```bash
   chmod +x "$SCRIPT_FILE"
   ```

### Step 6.5: Launch and Monitor Script (MANDATORY)

The agent MUST actively monitor the script execution:

1. **Launch as background task** using Bash with `run_in_background: true`
   ```bash
   bash "$SCRIPT_FILE" > "$SESSION_DIR/execution.log" 2>&1 &
   echo $! > "$SESSION_DIR/script.pid"
   ```

2. **Monitor output in real-time** - check output every 30-60 seconds
   ```bash
   # Read the latest output
   tail -50 "$SESSION_DIR/execution.log"

   # Check if script is still running
   if [ -f "$SESSION_DIR/script.pid" ]; then
     kill -0 $(cat "$SESSION_DIR/script.pid") 2>/dev/null && echo "Running" || echo "Stopped"
   fi
   ```

3. **Watch for these patterns and respond**:

   | Pattern in Output | Meaning | Agent Action |
   |-------------------|---------|--------------|
   | `syntax error` or `parse error` | Script has bash bugs | Fix the generated script directly |
   | `grep: invalid` or `jq: error` | Bad regex/parsing logic | Fix the parsing logic in script |
   | Claude returns unexpected format | Prompt needs adjustment | Fix the prompt template in script |
   | `Could not find OLD_STRING` | Fix target is wrong | Let script's reflection handle it |
   | Target code errors | Expected behavior | Let script's fix mechanism handle |
   | All evaluations return 0% | Script's evaluation is broken | Fix the evaluation logic |

4. **Intervene when needed** - Don't wait for script to complete if it's clearly broken

**Decision Tree for Intervention:**
```
Script output shows error
  ├── Is error in the troubleshoot script itself?
  │     → FIX THE SCRIPT using Edit tool, then restart
  ├── Is error in parsing/extracting Claude responses?
  │     → FIX THE PARSING LOGIC in script, then restart
  ├── Is error in target code (the thing being diagnosed)?
  │     → This is EXPECTED - let script handle it
  ├── Is output format unparseable?
  │     → Fix output format requirements in prompts
  └── Is Claude returning wrong format?
      → Fix prompt to be more explicit about output format
```

**The agent has FULL AUTHORITY to modify:**
- The generated troubleshoot script (if it has bugs)
- The target script (through troubleshoot script OR directly if urgent)
- Any supporting files needed to make things work

### Step 7: Execute and Report

After execution completes:

**On Success:**
```
✅ Issue fixed!

Session: .claude/troubleshoot/{issue-name}/
Iterations: {count}
Fixes applied: {count}

Key learnings:
{extracted from state.json}

Verified output: .claude/troubleshoot/{issue-name}/verified-output
```

**On Failure:**
```
❌ Could not fix after {iterations} attempts

Session: .claude/troubleshoot/{issue-name}/
Termination: {reason}

Hypotheses tested:
{from state.json}

What was learned:
{learnings from attempted_fixes}

Next steps:
- Review state.json for full diagnostic history
- Check if hypotheses need expansion
- Consider manual investigation of {specific area}
```

---

## Important Rules

1. **Hypothesis-first** - Generate hypotheses before attempting fixes
2. **State persistence** - ALL learnings go to state.json
3. **No repetition** - Block fixes similar to previous failures
4. **External termination** - Script decides when to stop, not Claude
5. **Structured reflection** - Every attempt gets a post-mortem
6. **Multi-perspective** - When stuck, use multiple viewpoints
7. **Bayesian updates** - Update hypothesis confidence based on evidence
8. **Information gain** - Prefer diagnostic actions until confident

---

## Scope of Changes

The agent has authority to modify different files for different reasons:

| File Type | When to Modify | How to Modify |
|-----------|----------------|---------------|
| Generated troubleshoot script | Script has bugs (bad regex, syntax errors, broken parsing, logic issues) | Direct Edit - fix immediately |
| Target script (being diagnosed) | Through troubleshoot process | Via script's fix mechanism (hypotheses → fix → reflect) |
| Target script (urgent) | Script process is fundamentally broken AND issue is obvious | Direct Edit as last resort, then document |
| Build/pipeline scripts | They have bugs preventing diagnosis | Direct Edit, document what was fixed |
| Claude prompts in script | Claude returns wrong format | Direct Edit to improve prompt clarity |

**Key distinctions:**

1. **Script bugs vs Target bugs**
   - Script bugs: Agent fixes directly (this is tooling maintenance)
   - Target bugs: Script handles via structured process (this is the diagnosis)

2. **Why this matters**
   - If `grep -o '{.*}'` can't parse multi-line JSON → that's a SCRIPT bug → fix directly
   - If the target code has wrong logic → that's a TARGET bug → let script handle

3. **The troubleshoot process is for diagnosing UNKNOWNS**
   - When the agent KNOWS the script has bad regex, that's not an unknown
   - Fix it and move on

---

## Definition of Done

This section addresses premature completion - when agents stop after partial success instead of achieving the full objective.

### Understanding the Script's Full Scope

BEFORE monitoring begins, the agent MUST understand:
1. **What is the script trying to accomplish?** (Read the script's header comments, help text, or main logic)
2. **What does "complete" look like?** (All steps done? All tests passing? All targets processed?)
3. **What is the original user goal?** (Not just "run this script" but "what outcome do they want?")

### Completion Criteria

The troubleshooting session is NOT complete until:

| Scenario | Done When |
|----------|-----------|
| Script has multiple steps | ALL steps complete successfully |
| Script processes multiple files | ALL files processed |
| Script has a stated goal | Goal is achieved |
| Script runs in a loop | Loop terminates with success |
| User said "run until complete" | Script's full purpose is fulfilled |

### Anti-Pattern: Premature Success Declaration

**DO NOT** stop just because:
- One iteration passed (but there are more to go)
- The bug fix was verified (but original goal not achieved)
- The script didn't crash (but it didn't finish either)
- One step succeeded (but 4 more steps remain)

**Example of WRONG behavior:**
```
User: "Run build-pipeline.sh which builds steps 4, 5, 7, 8, 9"
Agent: *fixes bug* *runs --step 4* *step 4 passes*
Agent: "Done! Step 4 completed successfully!"  ← WRONG! 4 more steps remain!
```

**Example of CORRECT behavior:**
```
User: "Run build-pipeline.sh which builds steps 4, 5, 7, 8, 9"
Agent: *fixes bug* *runs with --resume or no flags*
Agent: *monitors until steps 4, 5, 7, 8, 9 ALL complete*
Agent: "Done! All 5 steps completed: 4 ✓ 5 ✓ 7 ✓ 8 ✓ 9 ✓"
```

### Resume with FULL Scope

After fixing a script bug:
1. **Re-run the script with its ORIGINAL intended scope**
2. **Do NOT limit scope just to verify the fix**
3. **Continue monitoring until the FULL objective is achieved**

**Wrong:** `--step 4` (just verifying the fix works)
**Right:** `--resume` or no flags (continuing the full mission)

### Detecting Full Scope

When the troubleshoot session starts, the agent should identify:

```markdown
## Session Scope
- Target script: {script path}
- Full objective: {what user actually wants accomplished}
- Success indicators:
  - [ ] {indicator 1 - e.g., "All 5 steps complete"}
  - [ ] {indicator 2 - e.g., "No errors in final output"}
  - [ ] {indicator 3 - e.g., "Success message displayed"}
```

The session is complete when ALL success indicators are checked off, not just when the script doesn't crash.

### Scope Tracking During Monitoring

When actively monitoring, track progress against the full scope:

```markdown
## Progress Tracking
Original scope: Steps 4, 5, 7, 8, 9

Current status:
- Step 4: ✓ Complete
- Step 5: ⏳ In progress
- Step 7: ⬜ Not started
- Step 8: ⬜ Not started
- Step 9: ⬜ Not started

Session complete: NO (2/5 done)
```

Only report completion when ALL items show ✓.

---

## Prompt Quality Requirements (Claude Syntax Rules)

All Claude prompts in the generated troubleshoot script MUST follow these rules for reliable, parseable output.

### 1. Use XML Tags for Structure

Claude was trained with XML tags, making them highly effective for structure. Use semantically meaningful names:

```xml
<role>Expert persona</role>
<task>What to do</task>
<context>Background information</context>
<instructions>Step-by-step guidance</instructions>
<constraints>Rules and limitations</constraints>
<example>Demonstration</example>
<output_format>Expected response structure</output_format>
```

### 2. Be Explicit About Output Format

Vague requests get vague results. Be extremely specific:

**BAD - causes parsing failures:**
```
Provide your analysis.
```

**GOOD - parseable output:**
```xml
<output_format>
Respond with ONLY a JSON object. No markdown code blocks, no explanation, just valid JSON:
{
  "analysis": "one sentence explaining the root cause",
  "fix": {
    "file": "path/to/file",
    "old_string": "exact text to find",
    "new_string": "replacement text"
  }
}
</output_format>
```

### 3. Tell Claude What TO Do (Not What NOT To Do)

Positive instructions outperform negative ones:

**Less Effective:**
```
Don't include explanations.
Don't use markdown.
```

**More Effective:**
```
Output ONLY the JSON object.
Start directly with the opening brace.
End with the closing brace.
```

### 4. Explain WHY for Constraints

Context helps Claude follow rules more reliably:

**Less Effective:**
```
OLD_STRING must be exact.
```

**More Effective:**
```
OLD_STRING must match EXACTLY what exists in the file, including whitespace
and line breaks, because the fix is applied using string replacement and
even one character difference will cause the fix to fail.
```

### 5. Include Examples for Complex Formats

For novel or complex output formats, include 2-3 examples:

```xml
<examples>
<example>
<input>TypeError: Cannot read property 'length' of undefined</input>
<output>
{
  "analysis": "Variable is undefined when accessed",
  "fix": {
    "file": "src/utils.js",
    "old_string": "return items.length",
    "new_string": "return items?.length ?? 0"
  }
}
</output>
</example>
</examples>
```

### 6. Use Role Prompting for Domain Accuracy

```xml
<role>
You are a systematic troubleshooter using hypothesis-driven diagnosis.
You analyze errors methodically and provide precise, minimal fixes.
You never add unnecessary changes or improvements beyond what's required.
</role>
```

### Common Prompt Issues That Cause Parsing Failures

| Issue | Symptom | Fix |
|-------|---------|-----|
| Vague output format | Claude adds explanation text | Add explicit `<output_format>` with "ONLY output JSON, no other text" |
| No examples | Claude guesses format | Add 1-2 concrete examples of exact expected output |
| Multiple formats accepted | Inconsistent output | Specify ONE exact format, reject alternatives |
| Negative instructions | Claude focuses on what not to do | Use positive instructions instead |
| No explanation of WHY | Claude breaks rules when they seem unimportant | Explain why each constraint matters |

### Standard Prompt Template for Troubleshoot Scripts

Use this template structure for all Claude calls in generated scripts:

```xml
<role>
You are a systematic troubleshooter analyzing [problem type].
You provide precise, minimal fixes with exact string matching.
</role>

<task>
[Clear, specific objective - one sentence]
</task>

<context>
Problem: [description]
File: [path]
Current error: [error message or symptom]
Previous attempts: [what has been tried]
</context>

<current_state>
[State JSON or relevant data]
</current_state>

<instructions>
1. Analyze the current error/symptom
2. Update hypothesis confidence based on evidence
3. Propose ONE specific action (diagnostic or fix)
4. If proposing a fix, provide exact OLD_STRING and NEW_STRING
</instructions>

<constraints>
- OLD_STRING must match EXACTLY including all whitespace (because string replacement fails otherwise)
- Propose only ONE action per response (because we test hypotheses one at a time)
- Do not include markdown code blocks in JSON output (because they break JSON parsing)
- Start your response directly with the opening brace (because any prefix text breaks parsing)
</constraints>

<output_format>
Respond with ONLY this JSON object, no other text:
{
  "hypothesis_updates": [
    {"id": "H1", "confidence_change": "+10", "reason": "evidence supports this"}
  ],
  "action": {
    "type": "FIX",
    "target_hypothesis": "H1",
    "description": "what we're doing and why",
    "expected_if_correct": "what happens if hypothesis is right",
    "expected_if_wrong": "what happens if hypothesis is wrong"
  },
  "fix": {
    "file": "path/to/file.ext",
    "old_string": "exact text to find including\\nnewlines",
    "new_string": "replacement text"
  }
}
</output_format>
```

---

## Execution Model

### Agent Steps

1. **Generate the troubleshoot script** using the Write tool
2. **Execute as background task** — use `run_in_background: true` in Bash tool
3. **Monitor output** — read execution log every 30-60 seconds
4. **Identify failure points** — distinguish between:
   - Target code bugs (expected — script will fix)
   - Script bugs (unexpected — fix directly)
   - Infrastructure issues (permissions, missing tools, etc.)
5. **Fix script bugs directly** — if the troubleshoot script has bad logic, bad regex, broken heredocs, or broken parsing, fix using Edit tool
6. **Resume/re-run after fixes** — re-run the script after fixing script bugs

### What the Agent Must NOT Do

- **DO NOT** apply fixes to target code WITHOUT using the structured troubleshoot process (the script is the mechanism for applying fixes)
- **DO NOT** give up when the script fails due to script bugs - FIX THE SCRIPT
- **DO NOT** tell user to "test manually" - the script handles testing
- **DO NOT** just wait passively for script to complete without monitoring
- **DO NOT** assume the script is correct - if it produces broken output, fix it

### Decision Tree for Script Problems

```
Script execution shows problem
  │
  ├── ERROR: bash syntax error
  │     └── Agent: Fix script syntax, re-run
  │
  ├── ERROR: grep/sed/jq parsing fails
  │     └── Agent: Fix parsing logic in script, re-run
  │
  ├── ERROR: Claude returns unparseable response
  │     └── Agent: Fix prompt in script to be more explicit, re-run
  │
  ├── ERROR: JSON extraction fails (e.g., grep -o '{.*}' on multiline)
  │     └── Agent: Replace with proper JSON extraction, re-run
  │
  ├── All evaluations show 0%
  │     └── Agent: The evaluation logic is broken - fix it, re-run
  │
  ├── ERROR: in target code (expected)
  │     └── Script handles this via its fix mechanism
  │
  └── INFO: Script running normally
        └── Continue monitoring
```

### The Script is a TOOL

**Key principle**: The troubleshoot script is a TOOL the agent creates. If the tool is broken, the agent fixes the tool.

The constraint is that target code fixes should go through the script's structured process (hypotheses, reflection, learning). But when the SCRIPT ITSELF has bugs (wrong regex, bad parsing, broken prompts), the agent MUST fix those directly - that's not bypassing the process, that's fixing the tooling.

### Monitoring Pattern

```bash
# Launch in background
bash "$SCRIPT_FILE" > "$SESSION_DIR/execution.log" 2>&1 &
SCRIPT_PID=$!
echo "$SCRIPT_PID" > "$SESSION_DIR/script.pid"

# Check periodically
while kill -0 $SCRIPT_PID 2>/dev/null; do
  sleep 30

  # Look for script bugs (not target code bugs)
  if grep -q "syntax error\|parse error\|jq: error\|grep: invalid" "$SESSION_DIR/execution.log"; then
    echo "Script has bugs - agent should fix"
    # Agent reads log, identifies issue, fixes script with Edit tool
    break
  fi

  # Show recent output
  tail -20 "$SESSION_DIR/execution.log"
done
```

Or launch with Task tool for better background handling.

---

## Flow Summary

```
1. /pm:troubleshoot invoked
   │
   ▼
2. Initialize session directory
   │
   ▼
3. Ask 3 simple questions (AskUserQuestion)
   │
   ▼
4. Read target script
   │
   ▼
5. Generate troubleshoot script with:
   │  - Initial hypotheses
   │  - State management
   │  - Anti-repetition check
   │  - Termination criteria
   │  - Reflection prompts
   │
   ▼
6. Launch script as background task (MANDATORY)
   │
   ▼
6.5. ACTIVELY MONITOR (MANDATORY) ←── KEY CHANGE
   │  - Check output every 30-60 seconds
   │  - Watch for script bugs vs target bugs
   │  - FIX SCRIPT BUGS DIRECTLY if found
   │  - Let script handle target bugs
   │  - Re-run after fixing script bugs
   │  - TRACK PROGRESS AGAINST FULL SCOPE ←── NEW
   │
   ▼
7. Script runs autonomously
   │  - Loops with ANALYZE → DECIDE → ACT → REFLECT
   │  - Updates state.json each iteration
   │  - Terminates on success OR max iterations OR stuck
   │
   ▼
8. CHECK DEFINITION OF DONE ←── NEW
   │  - Did ALL steps/targets complete? (not just one)
   │  - Was the ORIGINAL user objective achieved?
   │  - If NO: continue monitoring or re-run with full scope
   │  - If YES: proceed to report
   │
   ▼
9. Report results with learnings
   │  - Show completion status for EACH step/target
   │  - Confirm full objective was achieved
```

---

## References

- **StateAct Pattern**: Explicit state tracking improves performance 7-30%
- **Reflexion**: Verbal reinforcement learning for agents
- **MAR (Multi-Agent Reflexion)**: Diverse perspectives prevent degeneration-of-thought
- **External Termination**: System enforces stopping, not agent
- **Hypothesis-Driven Diagnosis**: Clinical differential diagnosis model

See: `research-report-troubleshooting-loops.md` for full research citations.

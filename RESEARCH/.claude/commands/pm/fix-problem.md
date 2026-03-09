# Fix Problem

Autonomous problem-fixing agent that gathers context from codebase, logs, and K8s artifacts to diagnose and fix errors. Uses deep research for solutions and retries up to 3 times with different approaches.

Supports two modes:
1. **Error Mode** - Diagnose and fix a provided error message
2. **Command Mode** - Execute a command repeatedly until it succeeds, with automatic fixes between retries

## Usage

### Error Mode (Original)
```
/pm:fix-problem "<error_message>" --desired "<expected_behavior>" [--test "<verification_command>"] [--namespace "<k8s_namespace>"]
```

### Command Mode (New)
```
/pm:fix-problem --command "<command_to_run>" --desired "<expected_behavior>" [--auto] [--inputs <file>] [--timeout <seconds>] [--max-attempts <N>] [--backoff <initial_delay>] [--circuit-breaker <threshold>] [--namespace "<k8s_namespace>"]
```

**Arguments:**

| Parameter | Default | Mode | Description |
|-----------|---------|------|-------------|
| `error_message` | - | Error | The error output to diagnose and fix |
| `--desired` | - | Both | Description of expected correct behavior (required) |
| `--command` | - | Command | Command to execute (enables command mode) |
| `--test` | - | Error | Command to verify the fix worked |
| `--auto` | false | Command | Fully autonomous mode - auto-generates inputs for interactive prompts |
| `--inputs` | auto-detect | Command | Path to inputs file (from `/pm:generate-inputs`) |
| `--timeout` | 120 | Command | Timeout per command execution in seconds |
| `--max-attempts` | 5 | Command | Maximum command retry attempts |
| `--backoff` | 1 | Command | Initial backoff delay in seconds (doubles each retry, max 60s) |
| `--circuit-breaker` | 3 | Command | Open circuit after N identical errors |
| `--namespace` | - | Both | K8s namespace to check for resources/logs |

**Examples:**
```bash
# Error mode - fix a specific error
/pm:fix-problem "TypeError: undefined" --desired "Function returns array"

# Command mode - run until success
/pm:fix-problem --command "npm run build" --desired "Build succeeds"

# Command mode with K8s
/pm:fix-problem --command "kubectl apply -f deploy.yaml" --desired "Pods running" --namespace myapp

# Command mode with custom retry settings
/pm:fix-problem --command "./run-tests.sh" --timeout 300 --max-attempts 5 --desired "All tests pass"

# FULLY AUTONOMOUS - generates inputs for interactive prompts
/pm:fix-problem --command "./setup.sh" --desired "Setup completes" --auto

# Use pre-generated inputs file
/pm:fix-problem --command "./setup.sh" --desired "Setup completes" --inputs .claude/inputs/setup-inputs.yaml
```

## Workflow

### Phase 0: Command Execution Mode (if --command provided)

When `--command` is provided, the agent enters a ReAct (Reason-Act-Observe) loop:

```
┌─────────────────────────────────────────────────────────┐
│              Command Execution Loop                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  0. (If --auto) Load or generate inputs file            │
│     - Check: .claude/inputs/{command_hash}-inputs.yaml  │
│     - If missing: Run /pm:generate-inputs first         │
│                                                         │
│  1. Execute command (with timeout + input piping)       │
│     - If inputs file exists: pipe or use expect         │
│     - Capture stdout/stderr                             │
│                                                         │
│  2. Check exit code                                     │
│     - 0: SUCCESS → exit loop                            │
│     - Non-0: Continue to step 3                         │
│                                                         │
│  3. Capture stdout/stderr as error_message              │
│  4. Pattern match for known error types                 │
│     - "waiting for input" → regenerate inputs           │
│     - Build/test errors → continue to fix               │
│                                                         │
│  5. Circuit breaker check                               │
│     - Hash the error message                            │
│     - If same hash seen N times: OPEN → escalate        │
│     - Different errors: continue                        │
│                                                         │
│  6. Continue to Phase 1-8 with captured error           │
│     - Diagnose, research, apply fix                     │
│                                                         │
│  7. Wait with exponential backoff (1,2,4,8,16...max 60) │
│                                                         │
│  8. Increment attempt counter                           │
│     - Max reached: Escalate to human                    │
│     - Otherwise: Loop to step 1                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Auto Mode Input Handling:**

When `--auto` is specified, fix-problem handles interactive prompts automatically.

### Step A1: Check for Existing Inputs File

```bash
SCRIPT_NAME=$(basename "$COMMAND" | sed 's/[^a-zA-Z0-9]/-/g')
INPUTS_FILE=".claude/inputs/${SCRIPT_NAME}-inputs.yaml"

if [ -f "$INPUTS_FILE" ]; then
  echo "Using existing inputs: $INPUTS_FILE"
else
  # Need to generate inputs - continue to Step A2
fi
```

### Step A2: Spawn generate-inputs Sub-Task (if needed)

**YOUR ACTION:** Use the Task tool to spawn a sub-agent.

**Prompt engineering notes:**
- XML tags separate task definition from security constraints
- Role prompting establishes input analysis expertise
- Clear output format with security boundary

```yaml
Task tool parameters:
  subagent_type: "general-purpose"
  description: "Generate inputs for {command}"
  prompt: |
    <role>
    You are an input analyzer generating test inputs for interactive scripts.
    Your job is to analyze scripts, identify prompts they will ask, and generate
    sensible default values based on project context.
    </role>

    <task>
    Run /pm:generate-inputs for command: "{command}"
    Output file: .claude/inputs/{script_name}-inputs.yaml

    Analyze the script/command to identify input prompts.
    Research project context (git config, package.json, .env, README).
    Generate viable test inputs with confidence scores.
    </task>

    <security_constraints>
    CRITICAL: Never auto-fill credentials, secrets, or API keys.
    Mark any credential fields as deferred with source: "user_required".
    This protects against accidentally exposing or guessing sensitive values.
    </security_constraints>

    <output_format>
    Return ONLY the path to the generated inputs file:
    .claude/inputs/{script_name}-inputs.yaml
    </output_format>
```

### Step A3: Verify Inputs File Was Created

```bash
test -f "$INPUTS_FILE" || { echo "❌ generate-inputs failed"; exit 1; }
echo "✓ Inputs file ready: $INPUTS_FILE"
```

### Step A4: Execute Command with Inputs

```bash
# Check if expect script is defined
EXPECT_SCRIPT=$(yq -r '.expect_script // empty' "$INPUTS_FILE")

if [ -n "$EXPECT_SCRIPT" ]; then
  # Complex interactive: use expect
  echo "$EXPECT_SCRIPT" | expect -
else
  # Simple: pipe values directly
  yq -r '.inputs[].value' "$INPUTS_FILE" | $COMMAND
fi
```

**Input File Resolution Priority:**
```
1. --inputs flag value (explicit path)
2. .claude/inputs/{script_name}-inputs.yaml (existing)
3. SPAWN /pm:generate-inputs sub-task (if --auto)
4. FAIL with clear message (if interactive and no inputs)
```

**State Management:**

Store execution state in `.claude/fixes/{command_hash}/`:
```
state.json           # Current attempt, circuit state, error hashes
attempt_1.log        # stdout/stderr from attempt 1
attempt_1_fix.md     # Fix applied after attempt 1
attempt_2.log        # etc.
```

**state.json structure:**
```json
{
  "command": "npm run build",
  "command_hash": "a1b2c3d4",
  "desired": "Build succeeds",
  "started": "2024-01-15T10:30:00Z",
  "current_attempt": 2,
  "max_attempts": 5,
  "backoff_seconds": 2,
  "circuit_breaker": {
    "threshold": 3,
    "error_hashes": ["abc123", "abc123"],
    "state": "CLOSED"
  },
  "attempts": [
    {
      "number": 1,
      "timestamp": "2024-01-15T10:30:00Z",
      "exit_code": 1,
      "error_hash": "abc123",
      "fix_applied": "Added missing dependency",
      "duration_seconds": 45
    }
  ]
}
```

### Circuit Breaker Execution

After each failed attempt, execute these steps:

**Step C1: Hash the Error**
```bash
# Hash first 200 chars + error type for deduplication
ERROR_HASH=$(echo "$ERROR_OUTPUT" | head -c 200 | md5sum | cut -d' ' -f1)
echo "Error hash: $ERROR_HASH"
```

**Step C2: Update State File**
```bash
# Add hash to history
jq ".circuit_breaker.error_hashes += [\"$ERROR_HASH\"]" state.json > tmp && mv tmp state.json

# Read last N hashes (N = threshold)
THRESHOLD=$(jq -r '.circuit_breaker.threshold' state.json)
LAST_HASHES=$(jq -r ".circuit_breaker.error_hashes[-$THRESHOLD:][]" state.json)
```

**Step C3: Check for Consecutive Identical Errors**
```bash
# Count unique hashes in last N
UNIQUE_COUNT=$(echo "$LAST_HASHES" | sort -u | wc -l)

if [ "$UNIQUE_COUNT" -eq 1 ] && [ "$(echo "$LAST_HASHES" | wc -l)" -ge "$THRESHOLD" ]; then
  # All last N errors are identical - OPEN circuit
  jq '.circuit_breaker.state = "OPEN"' state.json > tmp && mv tmp state.json
  echo "❌ Circuit OPEN - same error $THRESHOLD times"
  # Exit to escalation output
  exit 1
fi
```

### Between-Attempt Verification

After applying a fix and before running the next attempt:

**Step V1: Verify Fix Was Applied**
```bash
# Check git shows changes
CHANGES=$(git diff --stat HEAD 2>/dev/null | tail -1)
if [ -z "$CHANGES" ]; then
  echo "⚠️ Warning: No code changes detected from fix"
fi
```

**Step V2: Update State File**
```bash
ATTEMPT=$(jq -r '.current_attempt' state.json)
jq ".attempts[$ATTEMPT].fix_verified = true" state.json > tmp && mv tmp state.json
```

**Step V3: Wait with Exponential Backoff**
```bash
INITIAL_BACKOFF=$(jq -r '.backoff_seconds // 1' state.json)
ATTEMPT=$(jq -r '.current_attempt' state.json)
BACKOFF=$((INITIAL_BACKOFF * (2 ** (ATTEMPT - 1))))
BACKOFF=$((BACKOFF > 60 ? 60 : BACKOFF))
echo "Waiting ${BACKOFF}s before retry..."
sleep $BACKOFF
```

### Command Execution

**Step E1: Execute with Timeout**
```bash
OUTPUT=$(timeout ${TIMEOUT_SECONDS:-120} bash -c "${COMMAND}" 2>&1)
EXIT_CODE=$?
```

**Step E2: Check Result**
```bash
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ Command succeeded"
  jq '.status = "success"' state.json > tmp && mv tmp state.json
  # Report success and exit
  exit 0
fi

# Timeout returns 124
if [ $EXIT_CODE -eq 124 ]; then
  ERROR_TYPE="timeout"
else
  ERROR_TYPE="error"
fi

# Capture output as error_message for Phase 1+
ERROR_MESSAGE="$OUTPUT"
```

**Step E3: Log Attempt**
```bash
ATTEMPT=$(jq -r '.current_attempt' state.json)
echo "$OUTPUT" > "attempt_${ATTEMPT}.log"
jq ".current_attempt = $((ATTEMPT + 1))" state.json > tmp && mv tmp state.json
```

### Phase 1: Parse Input

Extract error details from arguments:
```yaml
error:
  message: {raw error text}
  source: {test|build|runtime|logs|k8s}

desired:
  behavior: {expected behavior description}
  test_command: {verification command if provided}
  namespace: {k8s namespace if provided}
```

### Phase 2: Generate Clarifying Questions

Generate 10-15 questions across four layers:

#### Layer 1: Error Context
1. What is the exact error type? (syntax, runtime, timeout, permission, etc.)
2. What file/line is the error occurring in?
3. What function/method is involved?
4. When did this start happening?

#### Layer 2: Code Context
5. What does the failing code do?
6. What are the inputs/outputs expected?
7. What dependencies are involved?
8. Are there similar patterns elsewhere that work?

#### Layer 3: Environment Context
9. What K8s resources are involved? (if applicable)
10. What environment variables are relevant?
11. What is the deployment state?
12. Are there related log entries?

#### Layer 4: Historical Context
13. Has this code been modified recently?
14. Are there similar past issues in git history?
15. What do the tests expect?

### Phase 3: Answer Questions Autonomously

For each question, use appropriate tools without asking the user:

| Question Type | Primary Tool | Strategy | Fallback |
|---------------|--------------|----------|----------|
| Error type | Pattern match | Parse error message for keywords | Default to "unknown" |
| Error location | Regex | Extract from stack trace `/at .* \((.*):(\d+):\d+\)/` | Grep error text |
| Function | Grep | Find function definition in codebase | Parse stack trace |
| Purpose | Read | Read function and docstring | Infer from name |
| Inputs/outputs | Read | Check type annotations | Analyze test files |
| Dependencies | Read | Check imports, package.json | Parse error message |
| Recent changes | Bash | `git log --oneline -10 -- {file}` | `git log -20` |
| Similar patterns | Grep | Search for similar working code | Check test files |
| K8s state | Bash | `kubectl get pods -n {namespace}` | `kubectl describe` |
| Log entries | Bash | `grep -B5 -A5 "{error}" logs/` | `tail -100 {log}` |
| Test expectations | Read | Find and read test file | Grep for assertions |

**Example context gathering:**
```bash
# Q1: Error type
# Parse: "TypeError: Cannot read properties of undefined (reading 'map')"
# Answer: Runtime error - null/undefined reference

# Q2: Location
# Extract from stack trace
grep -n "renderList" src/**/*.{ts,tsx,js,jsx}

# Q7: Recent changes
git log --oneline -10 -- src/components/Dashboard.tsx

# Q9: K8s state
kubectl get pods -n {namespace} -o wide
kubectl describe pod {failing_pod} -n {namespace}
```

### Phase 4: Synthesize Research Query

Based on gathered context, formulate a research query:

```markdown
## Context Summary
- Error: {classified_error_type}
- Location: {file}:{line}
- Function: {function_name}
- Root Cause Hypothesis: {hypothesis from context}
- Tech Stack: {detected technologies}
- Environment: {k8s/local/etc}

## Generated Research Query
"How to fix {error_type} in {tech_stack} when {root_cause_hypothesis}
best practices defensive programming {year}"
```

### Phase 5: Research Solution

Use WebSearch to find solutions:
```bash
# Search for solutions
WebSearch: "{generated_research_query}"

# Fetch detailed content from top results
WebFetch: {relevant_urls}
```

Extract from research:
- Fix description
- Code patterns to apply
- Files to modify
- Verification steps
- Alternative approaches

### Phase 6: Apply Fix

Write changes to identified files using Edit/Write tools.

### Phase 7: Verify Fix

```bash
if [ -n "{test_command}" ]; then
  {test_command}
  if [ $? -eq 0 ]; then
    echo "✅ Fix verified"
    # Complete
  else
    # Retry with different approach
  fi
fi
```

### Phase 8: Retry Loop (if verification fails)

Maximum 3 attempts with different approaches:

| Attempt | Approach | Description |
|---------|----------|-------------|
| 1 | **Direct Fix** | Apply most obvious fix from research |
| 2 | **Defensive Approach** | Add null checks, validation, error handling |
| 3 | **Alternative Pattern** | Try different implementation approach entirely |
| Escalate | **Human Handoff** | Document findings, stop with full context |

**Approach variation examples:**

```javascript
// Attempt 1: Direct Fix
data?.map(item => ...) ?? []

// Attempt 2: Defensive Approach
if (!data) {
  console.warn('Data is null/undefined');
  return [];
}
if (!Array.isArray(data)) {
  console.warn('Data is not an array:', typeof data);
  return [];
}
return data.map(item => item?.value ?? null);

// Attempt 3: Alternative Pattern
const safeData = Array.isArray(data) ? data : [];
return safeData.flatMap(item =>
  item?.value != null ? [item.value] : []
);
```

### Phase 9: Error Classification

Classify errors to determine retry strategy:

**Transient Errors - Retry with Exponential Backoff:**
- timeout, ETIMEDOUT, timed out
- connection refused, ECONNREFUSED
- 503 Service Unavailable
- 429 Too Many Requests
- network error, socket hang up

**Fixable Errors - Retry with Different Approach:**
- SyntaxError, syntax error
- TypeError, type error
- Cannot read property, undefined is not
- ImportError, ModuleNotFoundError
- ReferenceError, is not defined
- null pointer, NullPointerException

**Permanent Errors - Escalate Immediately (No Retry):**
- Authentication failed, 401 Unauthorized
- Permission denied, 403 Forbidden
- Invalid API key, token expired
- Schema violation, constraint violation

## Output

### Success
```markdown
## Fix Applied ✅

### Error Summary
- **Type**: {error_classification}
- **Location**: {file}:{line}
- **Function**: {function_name}

### Root Cause
{hypothesis_with_evidence}

### Context Gathered
{summarized_answers_to_key_questions}

### Fix Applied
- **Approach**: Attempt {N} - {approach_name}
- **Files Modified**:
  - {file1}: {change_description}
  - {file2}: {change_description}

### Verification
- **Command**: {test_command}
- **Result**: PASS ✅
- **Retries Used**: {count}/3

### Research Sources
- {source1}
- {source2}
```

### Failure (After 3 Retries)
```markdown
## Fix Failed ❌ - Escalate to Human

### Error Summary
- **Type**: {error_classification}
- **Location**: {file}:{line}
- **Classification**: {transient|fixable|permanent}

### Attempts Made
1. **Direct Fix**: {description} - {why_it_failed}
2. **Defensive Approach**: {description} - {why_it_failed}
3. **Alternative Pattern**: {description} - {why_it_failed}

### Context Gathered
{full_context_summary}

### Suggested Next Steps
1. {suggestion_based_on_findings}
2. {alternative_investigation_path}
3. Manual review of: {specific_files_or_configs}

### Raw Error Output
{last_error_output}
```

### Command Mode Success
```markdown
## Command Execution Complete ✅

### Summary
- **Command**: {command}
- **Result**: SUCCESS
- **Attempts Used**: {count}/{max_attempts}
- **Total Duration**: {duration}s

### Execution History
| Attempt | Exit Code | Error Type | Fix Applied | Duration |
|---------|-----------|------------|-------------|----------|
| 1 | 1 | SyntaxError | Fixed import statement | 45s |
| 2 | 0 | - | - | 12s |

### Fixes Applied
1. **Attempt 1**: {fix_description}
   - Files: {files_modified}

### State File
`.claude/fixes/{command_hash}/state.json`
```

### Command Mode Failure (Circuit Breaker or Max Attempts)
```markdown
## Command Execution Failed ❌ - Escalate to Human

### Summary
- **Command**: {command}
- **Result**: FAILED
- **Reason**: {circuit_breaker_opened | max_attempts_reached}
- **Attempts Used**: {count}/{max_attempts}

### Circuit Breaker Status
- **State**: OPEN
- **Trigger**: Same error repeated {N} times
- **Error Hash**: {hash}

### Execution History
| Attempt | Exit Code | Error Type | Fix Attempted | Result |
|---------|-----------|------------|---------------|--------|
| 1 | 1 | BuildError | Added dependency | Still failed |
| 2 | 1 | BuildError | Fixed config | Still failed |
| 3 | 1 | BuildError | - | Circuit opened |

### Error Pattern (Repeated)
```
{common_error_output}
```

### Suggested Next Steps
1. {suggestion_based_on_pattern}
2. Review state file: `.claude/fixes/{command_hash}/`
3. Manual investigation of: {specific_area}

### State File
`.claude/fixes/{command_hash}/state.json`
```

## Anti-Pattern Prevention

**FORBIDDEN:**
- ❌ Retrying without changing anything between attempts
- ❌ Applying the same fix twice
- ❌ Ignoring circuit breaker state (continuing after OPEN)
- ❌ Modifying files without git safety (stash first)
- ❌ Running indefinitely on transient errors without backoff
- ❌ Auto-filling credentials when spawning generate-inputs
- ❌ Skipping verification between attempts

**REQUIRED:**
- ✅ Fresh error analysis each retry (error may have changed)
- ✅ Different approach each retry attempt
- ✅ Respect circuit breaker threshold
- ✅ Persist state after each attempt for resumability
- ✅ Verify fix was applied before next attempt
- ✅ Wait with exponential backoff between retries
- ✅ Log all attempts to state file

## Important Rules

### Both Modes
1. **Never ask humans** - Answer ALL questions using tools
2. **Classify errors first** - Determine if retry is appropriate
3. **Vary approaches** - Each retry must try something meaningfully different
4. **Document everything** - Full audit trail of context gathered
5. **Fail gracefully** - If max retries fail, escalate with complete context
6. **Idempotent operations** - Changes should be safe to retry
7. **Git safety** - Consider `git stash` before making changes

### Command Mode Specific
8. **Respect circuit breaker** - Stop when same error repeats N times
9. **Honor timeouts** - Kill command if exceeds timeout, classify as timeout error
10. **Persist state** - Write state.json after each attempt for resumability
11. **Fresh context each retry** - Error may have changed, re-analyze each time
12. **Exponential backoff** - Wait between retries to allow transient issues to resolve

## Integration with Pipeline

### Error Mode (existing integration)
When called from `interrogate.sh` pipeline with a captured error:

```bash
# Pipeline calls fix_problem on failure
if ! execute_step 10; then  # deploy failed
  for attempt in 1 2 3; do
    /pm:fix-problem "{last_error}" \
      --desired "Deployment completes successfully with all pods running" \
      --test "kubectl get pods -n {namespace} | grep -v Running | grep -v Completed | wc -l | grep -q '^0$'" \
      --namespace "{namespace}"

    if [ $? -eq 0 ]; then
      break  # Fixed, continue pipeline
    fi
  done
fi
```

### Command Mode (new - recommended for pipeline)
Simpler integration - let fix-problem handle the retry loop:

```bash
# Single call - fix-problem handles retries internally
/pm:fix-problem \
  --command "./interrogate.sh --extract testapp" \
  --desired "Scope document created" \
  --max-attempts 5 \
  --timeout 300

# For K8s deployments
/pm:fix-problem \
  --command "kubectl apply -f k8s/" \
  --desired "All pods running" \
  --namespace "myapp" \
  --circuit-breaker 3

# In pipeline-lib.sh
run_step_with_fix() {
  local step_command="$1"
  local desired="$2"

  /pm:fix-problem \
    --command "$step_command" \
    --desired "$desired" \
    --max-attempts 3 \
    --timeout 600
}
```

## Relationship with Other Commands

| Command | Purpose |
|---------|---------|
| `/pm:deploy` | Deploy to K8s (may trigger fix_problem on failure) |
| `/pm:batch-process` | Process PRDs (may trigger fix_problem on failure) |
| `/dr` | Deep research (called internally for solutions) |
| `/pm:generate-remediation` | Create PRDs for issues found |

## Notes

### General
- Uses `/dr` pattern for solution research
- Modeled after Kubernetes reconciliation loops
- Each retry gathers fresh context (error may have changed)
- Logs all attempts to `.claude/fixes/` for audit trail

### Command Mode Architecture
- ReAct loop pattern (Reason-Act-Observe) from autonomous agent research
- Circuit breaker pattern from distributed systems (prevents infinite retry of unfixable errors)
- Exponential backoff for transient errors (network, rate limits, service availability)
- State persistence enables resumption after interruption
- Hash-based error deduplication identifies repeated failures

### Implementation References
- Error classification based on OWASP patterns and common runtime errors
- Retry logic follows AWS SDK retry patterns (exponential backoff with jitter candidate)
- Circuit breaker threshold based on typical transient error recovery times

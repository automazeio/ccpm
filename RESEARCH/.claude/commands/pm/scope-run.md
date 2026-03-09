# Scope Run

Execute a scope using an agentic test-driven loop.

## CRITICAL: Autonomous Operation

**DO NOT STOP. DO NOT ASK PERMISSION. KEEP LOOPING.**

This command runs autonomously until completion. You must:
- Loop continuously until `test.json.passed = true`
- After creating a PRD, immediately run `/pm:batch-process` on it
- After batch-process completes, immediately re-run tests
- Never pause to ask "should I continue?" - just continue
- Only stop when: passed=true OR same error 7x OR user sends Ctrl+C

If you find yourself wanting to ask permission, don't. Just do the next step.

## Usage
```
/pm:scope-run <scope-name>
```

## Core Loop

```
1. Load scope from .claude/scopes/{name}.md
2. Run tests → write to {codebase}/test.json
3. Read test.json
4. If passed=true → DONE
5. If passed=false → Claude analyzes failures, decides action:
   - Quick fix? → Fix directly
   - Complex? → Create PRD, run /pm:batch-process
   - Stuck (same error 7x)? → Escalate to human
6. Loop back to step 2
```

## test.json Schema

Located in the codebase root (e.g., `/home/ubuntu/gslr/test.json`):

```json
{
  "passed": false,
  "ran_at": "2026-01-09T07:30:00Z",
  "iteration": 3,
  "command": "npm test",
  "exit_code": 1,
  "summary": "3 passed, 2 failed",
  "failures": [
    {
      "test": "auth.test.ts",
      "error": "JWT validation failed",
      "file": "src/auth/jwt.ts",
      "line": 42
    }
  ]
}
```

## Test Command Auto-Detection

Claude detects test command from project structure:

| File | Command |
|------|---------|
| `package.json` | `npm test` |
| `*.csproj` | `dotnet test` |
| `pytest.ini` or `setup.py` | `pytest` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |
| `Makefile` with test target | `make test` |

Override in scope document:
```yaml
test_cmd: "npm run test:ci"
```

## Instructions

You are an agentic automation controller. You have judgment. Use it.

### Phase 1: Load Scope

1. Read `.claude/scopes/$ARGUMENTS.md`
2. Extract:
   - `work_dir` - Where the codebase lives
   - `test_cmd` - Optional override, otherwise auto-detect
   - `roadmap` - Path to roadmap.json for context

### Phase 2: Test Loop

```
iteration = 0
error_history = {}

while true:
    iteration++

    # Run tests
    cd {work_dir}
    result = run(test_cmd)

    # Write test.json
    write test.json with:
      - passed: true/false based on exit code
      - ran_at: current timestamp
      - iteration: current iteration
      - command: what was run
      - exit_code: result code
      - summary: parsed from output
      - failures: parsed error details

    # Check result
    if test.json.passed == true:
        log("All tests pass. Done.")
        break

    # Analyze failures
    for each failure in test.json.failures:
        error_sig = signature(failure)

        if error_sig in error_history:
            error_history[error_sig].count++
            if error_history[error_sig].count >= 7:
                log("Stuck on same error 7x. Escalating.")
                write "NEEDS_HUMAN: {error}" to test.json
                exit
        else:
            error_history[error_sig] = {count: 1}

    # Decide action (THIS IS WHERE YOU USE JUDGMENT)
    decide_and_act(test.json.failures)
```

### Phase 3: Decide and Act

For each failure, Claude decides:

**Option A: Quick Fix**
- Error is obvious (typo, missing import, simple bug)
- Fix directly, no PRD needed
- Continue to next test run

**Option B: Create PRD**
- Error is complex or architectural
- Create `.claude/prds/auto-fix-{n}-{slug}.md`
- Run `/pm:batch-process` to implement
- Continue to next test run

**Option C: Group Related Errors**
- Multiple failures have same root cause
- Create ONE PRD for all related errors
- More efficient than N separate PRDs

**Option D: UI/UX Enhancement**
- Claude notices opportunity for better UX
- Persona feedback suggests usability issues
- Missing feature that would improve user journey
- Create enhancement PRD (not bug fix)

**Option E: User/Persona Feedback**
- Persona testing reports friction points
- User journey doesn't feel natural
- Accessibility or mobile issues
- Create PRD based on feedback, iterate

**Option F: Escalate**
- Same error 7+ times
- Error is outside Claude's capability
- Requires human decision (e.g., "which database should we use?")
- Write status to test.json and stop

**Option G: Deploy Required**
- Test failures indicate deployment issue:
  - "Connection refused" to backend/frontend
  - "Service unavailable" (503, 502)
  - "ECONNREFUSED"
  - E2E test can't reach the running app
- OR code changes were made that need deployment to K8s
- Run `/pm:deploy {scope}` to build and deploy
- Continue loop after successful deploy

### Deploy Detection Heuristics

Call `/pm:deploy` when:
1. `scope.deploy.enabled = true` AND code files changed since last deploy
2. Test error contains: "ECONNREFUSED", "connection refused", "503", "502"
3. Test error mentions: "timeout", "service unavailable", "not running"
4. First iteration AND scope has `deploy.on_start = true`

Track deploys to avoid redundant builds:
```
deploy_tracker = {
  last_deploy: timestamp,
  files_changed_since: []
}

if should_deploy(test_failures, deploy_tracker):
    run("/pm:deploy {scope}")
    deploy_tracker.last_deploy = now()
    deploy_tracker.files_changed_since = []
```

### PRD Template for Auto-Fixes

```markdown
---
name: auto-fix-{n}-{slug}
status: backlog
priority: P0-critical
type: auto-fix
created: {timestamp}
---

# Auto-Fix: {Error Summary}

## Test Failure
```
{paste relevant failure from test.json}
```

## Analysis
{Claude's analysis of root cause}

## Fix
{What needs to change}

## Acceptance Criteria
- [ ] test.json.passed = true after fix
```

Keep it minimal. Let batch-process figure out the details.

## Scope Document Format

Minimal required fields:

```yaml
---
name: gslr
status: active
work_dir: /home/ubuntu/gslr
---

# GSLR Scope

Optional overrides:
- test_cmd: "dotnet test"
- max_iterations: 20
- roadmap: .claude/scopes/gslr-roadmap.json
```

### Deploy Configuration

Add deploy config to enable automatic deployment:

```yaml
---
name: gslr
status: active
work_dir: /home/ubuntu/gslr

deploy:
  enabled: true
  on_start: true          # Deploy before first test iteration
  build_script: ./build.sh
  namespace: gslr
---
```

When `deploy.enabled = true`:
- scope-run will call `/pm:deploy` when deployment is needed
- `on_start: true` triggers deploy before first test run
- `build_script` path is relative to work_dir
- `namespace` is the K8s namespace to verify pods

## Output

### During Execution
```
Loading scope: gslr
Work dir: /home/ubuntu/gslr
Test command: npm test (auto-detected)

=== Iteration 1 ===
Running tests...
test.json: passed=false, 2 failures
Analyzing: JWT validation failed
  → Quick fix: Missing JWT_SECRET env var
  → Fixed .env file
Continuing...

=== Iteration 2 ===
Running tests...
test.json: passed=false, 1 failure
Analyzing: Database connection refused
  → Complex issue: Need to configure PostgreSQL
  → Creating PRD: auto-fix-47-db-connection.md
  → Running batch-process...
Continuing...

=== Iteration 3 ===
Running tests...
test.json: passed=true
Done.
```

### On Success
```
=== SCOPE COMPLETE ===
Iterations: 3
PRDs created: 1
Time: 12m 34s
```

### On Escalation
```
=== NEEDS HUMAN ===
Stuck on: "Module not found: @angular/core"
Attempted: 7 times
Last PRD: auto-fix-49-angular-missing.md

Please investigate and re-run /pm:scope-run gslr
```

## Key Principles

1. **test.json is the source of truth** - Everything flows from test results
2. **Claude has judgment** - Not a rigid script, make smart decisions
3. **One PRD per root cause** - Group related errors
4. **Quick fixes don't need PRDs** - Obvious stuff, just fix it
5. **Escalate at 7** - Don't spin forever on the same error
6. **Keep PRDs minimal** - Let batch-process do the heavy lifting

## CRITICAL: Success Criteria

**test.json.passed = true ONLY when the app is FULLY FUNCTIONAL.**

NOT just "it compiles" or "tests pass". The app must:
- Run end-to-end (frontend + backend + database)
- Core features actually work
- Users can interact with the app

Check the scope document's "Success Criteria" section for specific requirements.
If the scope says "Admin can log in" then test that. Don't mark passed=true until it works.

**Examples of WRONG passed=true:**
- "Build succeeded" (code compiles ≠ app works)
- "No test failures" (if there are no tests, that's not success)
- "Frontend starts" (if backend is broken, app doesn't work)

**Examples of CORRECT passed=true:**
- All success criteria in scope doc are checked off
- End-to-end verification command exits 0
- A human could use the app for its intended purpose

## What This Is NOT

- Not a database auditor (test.json handles that via test failures)
- Not a discovery Q&A handler (that's a separate workflow)
- Not a roadmap enforcer (roadmap is for context, tests are for validation)

If you need those, use separate commands or build them into your test suite.

## REMEMBER

After EVERY action, ask yourself: "Is test.json.passed = true?"
- If NO → take the next action immediately
- If YES → stop and report success

Never ask the user:
- "Should I continue?"
- "Want me to proceed?"
- "Ready for the next step?"

Just do it.

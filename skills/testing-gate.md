---
name: testing:gate
description: Run merge-gate tests on the integration branch.
---

---
allowed-tools: Bash, Read, Write, LS, Task
---

# Gate Test Lane

Run the integration gate test lane after merge queue updates.

## Usage
```
/testing:gate
```

## Quick Check

```bash
test -f .claude/testing-config.md || echo "❌ Testing not configured. Run /testing:prime first"
```

## Instructions

### 1. Determine Lane Command

Read `.claude/testing-config.md` and choose the gate command:

- Prefer lane-specific entries if present:
  - Frontmatter: `gate_command`
  - Body: `Gate Lane` / `Gate Tests` / `Run Gate Tests`
- Otherwise, fall back to the general test command (`test_command` / `Run All Tests`).

If no distinct gate command is present, map this lane to the existing test runner
and note the scope as "gate" in the report.

### 2. Execute Tests

Use the test-runner agent from `.claude/agents/test-runner.md`:

```markdown
Execute tests for: gate lane

Requirements:
- Run with verbose output
- No mock services
- Capture full stack traces
- Analyze test structure if failures occur
```

### 3. Report Results

**Success:**
```
✅ Gate tests passed ({count} tests in {time}s)
```

**Failure:**
```
❌ Gate test failures: {failed_count} of {total_count}

{test_name} - {file}:{line}
  Error: {error_message}
  Likely: {test issue | code issue}
  Fix: {suggestion}
```

## Error Handling

- Command missing → "❌ No gate test command found. Configure in /testing:prime or add gate_command to testing-config.md."
- Test execution fails → "❌ Gate tests failed: {error}. Check framework install."

## Important Notes

- If no gate lane command exists, reuse the default test command.
- Always use the test-runner agent.

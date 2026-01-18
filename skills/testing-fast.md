---
name: testing:fast
description: Run the fast test lane on worker branches before merge.
---

---
allowed-tools: Bash, Read, Write, LS, Task
---

# Fast Test Lane

Run the fast test lane intended for worker branches.

## Usage
```
/testing:fast
```

## Quick Check

```bash
test -f .claude/testing-config.md || echo "❌ Testing not configured. Run /testing:prime first"
```

## Instructions

### 1. Determine Lane Command

Read `.claude/testing-config.md` and choose the fastest available command:

- Prefer lane-specific entries if present:
  - Frontmatter: `fast_command`
  - Body: `Fast Lane` / `Fast Tests` / `Run Fast Tests`
- Otherwise, fall back to the general test command (`test_command` / `Run All Tests`).

If no distinct fast command is present, map this lane to the existing test runner
and note the scope as "fast" in the report.

### 2. Execute Tests

Use the test-runner agent from `.claude/agents/test-runner.md`:

```markdown
Execute tests for: fast lane

Requirements:
- Run with verbose output
- No mock services
- Capture full stack traces
- Analyze test structure if failures occur
```

### 3. Report Results

**Success:**
```
✅ Fast tests passed ({count} tests in {time}s)
```

**Failure:**
```
❌ Fast test failures: {failed_count} of {total_count}

{test_name} - {file}:{line}
  Error: {error_message}
  Likely: {test issue | code issue}
  Fix: {suggestion}
```

## Error Handling

- Command missing → "❌ No fast test command found. Configure in /testing:prime or add fast_command to testing-config.md."
- Test execution fails → "❌ Fast tests failed: {error}. Check framework install."

## Important Notes

- If no fast lane command exists, reuse the default test command.
- Always use the test-runner agent.

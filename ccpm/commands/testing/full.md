---
allowed-tools: Bash, Read, Write, LS, Task
---

# Full Test Lane

Run the full verification test lane for epic closeout and roadmap completion.

## Usage
```
/testing:full
```

## Quick Check

```bash
test -f .claude/testing-config.md || echo "❌ Testing not configured. Run /testing:prime first"
```

## Instructions

### 1. Determine Lane Command

Read `.claude/testing-config.md` and choose the full-suite command:

- Prefer lane-specific entries if present:
  - Frontmatter: `full_command`
  - Body: `Full Lane` / `Full Tests` / `Run Full Tests`
- Otherwise, fall back to the general test command (`test_command` / `Run All Tests`).

If no distinct full command is present, map this lane to the existing test runner
and note the scope as "full" in the report.

### 2. Execute Tests

Use the test-runner agent from `.claude/agents/test-runner.md`:

```markdown
Execute tests for: full lane

Requirements:
- Run with verbose output
- No mock services
- Capture full stack traces
- Analyze test structure if failures occur
```

### 3. Report Results

**Success:**
```
✅ Full tests passed ({count} tests in {time}s)
```

**Failure:**
```
❌ Full test failures: {failed_count} of {total_count}

{test_name} - {file}:{line}
  Error: {error_message}
  Likely: {test issue | code issue}
  Fix: {suggestion}
```

## Error Handling

- Command missing → "❌ No full test command found. Configure in /testing:prime or add full_command to testing-config.md."
- Test execution fails → "❌ Full tests failed: {error}. Check framework install."

## Important Notes

- If no full lane command exists, reuse the default test command.
- Always use the test-runner agent.

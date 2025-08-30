---
allowed-tools: Bash, Read, Write, LS, Task
---

# Run Tests

Execute tests with the configured test-runner agent.

## Usage
```
/testing:run [test_target]
```

Where `test_target` can be:
- Empty (run all tests)
- Test file path
- Test pattern
- Test suite name

## Quick Check

```bash
# Check if testing is configured
test -f .claude/testing-config.md || echo "❌ Testing not configured. Run /testing:prime first"
```

If test target provided, verify it exists:
```bash
# For file targets
test -f "$ARGUMENTS" || echo "⚠️ Test file not found: $ARGUMENTS"
```

## Instructions

### 1. Determine Test Command

Based on testing-config.md and target:
- No arguments → Run full test suite from config
- File path → Run specific test file
- Pattern → Run tests matching pattern

### 2. Execute Tests

Use the test-runner agent from `.claude/agents/test-runner.md`:

```markdown
Execute tests for: $ARGUMENTS (or "all" if empty)

Requirements:
- Run with verbose output for debugging
- No mocks - use real services
- Capture full output including stack traces
- If test fails, check test structure before assuming code issue
```

### 3. Monitor Execution

- Show test progress
- Capture stdout and stderr
- Note execution time

### 4. Report Results

**Success:**
```
✅ All tests passed ({count} tests in {time}s)
```

**Failure:**
```
❌ Test failures: {failed_count} of {total_count}

{test_name} - {file}:{line}
  Error: {error_message}
  Likely: {test issue | code issue}
  Fix: {suggestion}

Run with more detail: /testing:run {specific_test}
```

**Mixed:**
```
Tests complete: {passed} passed, {failed} failed, {skipped} skipped

Failed:
- {test_1}: {brief_reason}
- {test_2}: {brief_reason}
```

### 5. Cleanup

```bash
# Kill any hanging test processes
pkill -f "jest|mocha|pytest" 2>/dev/null || true
```

## Error Handling

- Test command fails → "❌ Test execution failed: {error}. Check test framework is installed."
- Timeout → Kill process and report: "❌ Tests timed out after {time}s"
- No tests found → "❌ No tests found matching: $ARGUMENTS"

## Important Notes

- Always use test-runner agent for analysis
- No mocking - real services only
- Check test structure if failures occur
- Keep output focused on failures
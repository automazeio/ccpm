# Test Execution Rule

Standard patterns for running tests across all testing commands.

## Core Principles

1. **Always use test-runner agent** from `.claude/agents/test-runner.md`
2. **No mocking** - use real services for accurate results
3. **Verbose output** - capture everything for debugging
4. **Check test structure first** - before assuming code bugs

## Execution Pattern

```markdown
Execute tests for: {target}

Requirements:
- Run with verbose output
- No mock services
- Capture full stack traces
- Analyze test structure if failures occur
```

## Output Focus

### Success
Keep it simple:
```
✅ All tests passed ({count} tests in {time}s)
```

### Failure
Focus on what failed:
```
❌ Test failures: {count}

{test_name} - {file}:{line}
  Error: {message}
  Fix: {suggestion}
```

## Common Issues

- Test not found → Check file path
- Timeout → Kill process, report incomplete
- Framework missing → Install dependencies

## Cleanup

Always clean up after tests:
```bash
pkill -f "jest|mocha|pytest" 2>/dev/null || true
```

## Important Notes

- Don't parallelize tests (avoid conflicts)
- Let each test complete fully
- Report failures with actionable fixes
- Focus output on failures, not successes
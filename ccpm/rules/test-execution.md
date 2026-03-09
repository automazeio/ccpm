# Test Execution Rule

Standard patterns for running tests across all testing commands.

## Core Principles

1. Use the test-runner agent from `.claude/agents/test-runner.md`
2. Use real services — mocks produce inaccurate results
3. Capture verbose output for debugging
4. Check test structure before assuming code bugs

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
```
✅ All tests passed ({count} tests in {time}s)
```

### Failure
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

Kill test processes after each run (lingering processes can interfere with subsequent runs):
```bash
pkill -f "jest|mocha|pytest|phpunit|rspec|ctest" 2>/dev/null || true
pkill -f "mvn.*test|gradle.*test|gradlew.*test" 2>/dev/null || true
pkill -f "dotnet.*test|cargo.*test|go.*test|swift.*test|flutter.*test" 2>/dev/null || true
```

## Key Points

- Run tests sequentially — parallelizing them risks conflicts
- Let each test complete fully before starting the next
- Report failures with actionable fixes
- Focus output on failures, not successes

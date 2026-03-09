# Standard Patterns for Commands

Common patterns for all commands to maintain consistency and simplicity.

## Core Principles

1. **Fail Fast** — Check critical prerequisites, then proceed
2. **Trust the System** — Do not over-validate things that rarely fail
3. **Clear Errors** — When something fails, say exactly what and how to fix it
4. **Minimal Output** — Show what matters, skip decoration

## Standard Validations

### Minimal Preflight
Check only what is absolutely necessary:
```markdown
## Quick Check
1. If command needs a specific directory/file:
   - Check it exists: `test -f {file} || echo "{file} not found"`
   - If missing, tell the user the exact command to fix it
2. If command needs GitHub:
   - Assume `gh` is authenticated (it usually is)
   - Check only on actual failure
```

### DateTime Handling
```markdown
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
```
Reference `/rules/datetime.md` for full instructions.

### Error Messages
Short and actionable:
```markdown
{What failed}: {Exact solution}
Example: "Epic not found: Run /pm:prd-parse feature-name"
```

## Standard Output Formats

### Success Output
```markdown
✅ {Action} complete
  - {Key result 1}
  - {Key result 2}
Next: {Single suggested action}
```

### List Output
```markdown
{Count} {items} found:
- {item 1}: {key detail}
- {item 2}: {key detail}
```

### Progress Output
```markdown
{Action}... {current}/{total}
```

## File Operations

### Check and Create
```markdown
# Create what's needed without asking permission
mkdir -p .claude/{directory} 2>/dev/null
```

### Read with Fallback
```markdown
if [ -f {file} ]; then
  # Read and use file
else
  # Use sensible default
fi
```

## GitHub Operations

### Trust gh CLI
```markdown
# Try the operation; handle failure if it occurs
gh {command} || echo "GitHub CLI failed. Run: gh auth login"
```

### Simple Issue Operations
```markdown
# Get what you need in one call
gh issue view {number} --json state,title,body
```

## Patterns to Avoid

### Over-validation
```markdown
# Bad — too many checks
1. Check directory exists
2. Check permissions
3. Check git status
4. Check GitHub auth
5. Check rate limits
6. Validate every field

# Good — just what's needed
1. Check target exists
2. Try the operation
3. Handle failure clearly
```

### Verbose output
```markdown
# Bad — too much information
Starting operation...
Validating prerequisites...
Step 1 complete
Step 2 complete
Statistics: ...
Tips: ...

# Good — just results
Done: 3 files created
Failed: auth.test.js (syntax error - line 42)
```

### Excessive confirmation prompts
```markdown
# Bad — too interactive
"Continue? (yes/no)"
"Overwrite? (yes/no)"
"Are you sure? (yes/no)"

# Good — smart defaults
# Proceed with sensible defaults
# Ask only when destructive or ambiguous
"This will delete 10 files. Continue? (yes/no)"
```

## Quick Reference

### Tool Selection
- Read/List operations: `Read, LS`
- File creation: `Read, Write, LS`
- GitHub operations: add `Bash`
- Complex analysis: add `Task` (sparingly)

### Status Indicators
- `✅` Success (use sparingly)
- `❌` Error (always with solution)
- `⚠️` Warning (only if action needed)
- No emoji for normal output

### Exit Strategies
- Success: Brief confirmation
- Failure: Clear error + exact fix
- Partial: Show what worked, what did not

## Design Philosophy

Trust that the file system usually works, `gh` is usually authenticated, git repositories are usually valid, and users know what they are doing. Handle errors clearly when they occur; do not try to prevent every possible edge case.

# Standard Patterns for Commands

This file defines common patterns that all commands should follow to maintain consistency and simplicity.

## Core Principles

1. **Fail Fast** - Check critical prerequisites, then proceed
2. **Trust the System** - Don't over-validate things that rarely fail
3. **Clear Errors** - When something fails, say exactly what and how to fix it
4. **Minimal Output** - Show what matters, skip decoration

## Standard Validations

### Minimal Preflight
Only check what's absolutely necessary:
```markdown
## Quick Check
1. If command needs specific directory/file:
   - Check it exists: `test -f {file} || echo "❌ {file} not found"`
   - If missing, tell user exact command to fix it
2. If command needs GitHub:
   - Assume `gh` is authenticated (it usually is)
   - Only check on actual failure
```

### DateTime Handling
```markdown
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
```
Don't repeat full instructions - just reference `/rules/datetime.md` once.

### Error Messages
Keep them short and actionable:
```markdown
❌ {What failed}: {Exact solution}
Example: "❌ Epic not found: Run /pm:prd-parse feature-name"
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
# Don't ask permission, just create what's needed
mkdir -p .claude/{directory} 2>/dev/null
```

### Read with Fallback
```markdown
# Try to read, continue if missing
if [ -f {file} ]; then
  # Read and use file
else
  # Use sensible default
fi
```

## GitHub Operations

### Trust gh CLI
```markdown
# Don't pre-check auth, just try the operation
gh {command} || echo "❌ GitHub CLI failed. Run: gh auth login"
```

### Simple Issue Operations
```markdown
# Get what you need in one call
gh issue view {number} --json state,title,body
```

## Common Patterns to Avoid

### DON'T: Over-validate
```markdown
# Bad - too many checks
1. Check directory exists
2. Check permissions
3. Check git status
4. Check GitHub auth
5. Check rate limits
6. Validate every field
```

### DO: Check essentials
```markdown
# Good - just what's needed
1. Check target exists
2. Try the operation
3. Handle failure clearly
```

### DON'T: Verbose output
```markdown
# Bad - too much information
🎯 Starting operation...
📋 Validating prerequisites...
✅ Step 1 complete
✅ Step 2 complete
📊 Statistics: ...
💡 Tips: ...
```

### DO: Concise output
```markdown
# Good - just results
✅ Done: 3 files created
Failed: auth.test.js (syntax error - line 42)
```

### DON'T: Ask too many questions
```markdown
# Bad - too interactive
"Continue? (yes/no)"
"Overwrite? (yes/no)"
"Are you sure? (yes/no)"
```

### DO: Smart defaults
```markdown
# Good - proceed with sensible defaults
# Only ask when destructive or ambiguous
"This will delete 10 files. Continue? (yes/no)"
```

## Quick Reference

### Essential Tools Only
- Read/List operations: `Read, LS`
- File creation: `Read, Write, LS`
- GitHub operations: Add `Bash`
- Complex analysis: Add `Task` (sparingly)

### Status Indicators
- ✅ Success (use sparingly)
- ❌ Error (always with solution)
- ⚠️ Warning (only if action needed)
- No emoji for normal output

### Exit Strategies
- Success: Brief confirmation
- Failure: Clear error + exact fix
- Partial: Show what worked, what didn't

## Remember

**Simple is not simplistic** - We still handle errors properly, we just don't try to prevent every possible edge case. We trust that:
- The file system usually works
- GitHub CLI is usually authenticated  
- Git repositories are usually valid
- Users know what they're doing

Focus on the happy path, fail gracefully when things go wrong.
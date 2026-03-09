# Path Standards

Standards for file path usage within the Claude Code PM system to ensure document portability and privacy.

## Core Principles

- Use relative paths for project file references (absolute paths containing usernames break portability and expose local directory structure)
- Use project-root-relative paths in documentation
- Use sibling-relative paths (`../`) for cross-project or cross-worktree references

## Path Format Standards

### Project File References
```markdown
# Correct
- `internal/auth/server.go`
- `cmd/server/main.go`
- `.claude/commands/pm/sync.md`

# Incorrect
- `/Users/username/project/internal/auth/server.go`
- `C:\Users\username\project\cmd\server\main.go`
```

### Cross-Project/Worktree References
```markdown
# Correct
- `../project-name/internal/auth/server.go`
- `../worktree-name/src/components/Button.tsx`

# Incorrect
- `/Users/username/parent-dir/project-name/internal/auth/server.go`
- `/home/user/projects/worktree-name/src/components/Button.tsx`
```

### Code Comment File References
```go
// Correct
// See internal/processor/converter.go for data transformation
// Configuration loaded from configs/production.yml

// Incorrect
// See /Users/username/parent-dir/project-name/internal/processor/converter.go
```

## Implementation Rules

### Documentation Generation
1. **Issue sync templates**: Use relative path template variables
2. **Progress reports**: Convert absolute paths to relative paths automatically
3. **Technical documentation**: Use project root relative paths consistently

### Path Variable Standards
```yaml
project_root: "."              # Current project root directory
worktree_path: "../{name}"     # Worktree relative path
internal_path: "internal/"     # Internal modules directory
config_path: "configs/"        # Configuration files directory
```

### Automatic Cleanup
```bash
normalize_paths() {
  local content="$1"
  content=$(echo "$content" | sed "s|/Users/[^/]*/[^/]*/|../|g")
  content=$(echo "$content" | sed "s|/home/[^/]*/[^/]*/|../|g")
  content=$(echo "$content" | sed "s|C:\\\\Users\\\\[^\\\\]*\\\\[^\\\\]*\\\\|..\\\\|g")
  echo "$content"
}
```

## PM Command Integration

### issue-sync Command
- Clean path formats before sync
- Use relative path templates for generating comments
- Record deliverables using standardized paths

### epic-sync Command
- Standardize task file paths
- Clean GitHub issue body paths
- Use relative paths in mapping files

## Validation

### Check for Absolute Path Violations
```bash
check_absolute_paths() {
  echo "Checking for absolute path violations..."
  rg -n "/Users/|/home/|C:\\\\\\\\" .claude/ || echo "No absolute paths found"
}
```

### Manual Review Checklist
- [ ] GitHub Issue comments contain no absolute paths
- [ ] Local documentation uses relative paths consistently
- [ ] Code comment paths follow standards
- [ ] Configuration file paths are standardized

## When Absolute Paths Are Found in Published Content

1. Edit the GitHub Issues/comments immediately
2. Update local documentation
3. Update generation templates to prevent recurrence
4. Clean Git history only if necessary

## Example

```markdown
# Before
- Implemented `/Users/username/parent-dir/project-name/internal/auth/server.go` core logic

# After
- Implemented `../project-name/internal/auth/server.go` core logic
```

### GitHub Comment Format
```markdown
# Correct
## Deliverables
- `internal/formatter/batch.go` - Batch formatter
- `internal/processor/sorter.go` - Sorting algorithm
- `cmd/server/main.go` - Server entry point

# Incorrect
## Deliverables
- `/Users/username/parent-dir/project-name/internal/formatter/batch.go`
```

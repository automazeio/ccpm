# Branch Operations

Git branches enable parallel development by allowing multiple developers to work on the same repository with isolated changes.

## Creating Branches

Always create branches from a clean main branch:
```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create branch for epic
git checkout -b epic/{name}
git push -u origin epic/{name}
```

The branch will be created and pushed to origin with upstream tracking.

## Working in Branches

### Agent Commits
- Agents commit directly to the branch
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### File Operations
```bash
# Working directory is the current directory
# (no need to change directories like with worktrees)

# Normal git operations work
git add {files}
git commit -m "Issue #{number}: {change}"

# View branch status
git status
git log --oneline -5
```

## Parallel Work in Same Branch

Multiple agents can work in the same branch if they coordinate file access:
```bash
# Agent A works on API
git add src/api/*
git commit -m "Issue #1234: Add user endpoints"

# Agent B works on UI (coordinate to avoid conflicts!)
git pull origin epic/{name}  # Get latest changes
git add src/ui/*
git commit -m "Issue #1235: Add dashboard component"
```

## Merging Branches

When epic is complete, merge back to main:
```bash
# From main repository
git checkout main
git pull origin main

# Merge epic branch
git merge epic/{name}

# If successful, clean up
git branch -d epic/{name}
git push origin --delete epic/{name}
```

## Handling Conflicts

If merge conflicts occur:
```bash
# Conflicts will be shown
git status

# Human resolves conflicts
# Then continue merge
git add {resolved-files}
git commit
```

## Branch Management

### List Active Branches
```bash
git branch -a
```

### Remove Stale Branch
```bash
# Delete local branch
git branch -d epic/{name}

# Delete remote branch
git push origin --delete epic/{name}
```

### Check Branch Status
```bash
# Current branch info
git branch -v

# Compare with main
git log --oneline main..epic/{name}
```

## Best Practices

1. **One branch per epic** - Not per issue
2. **Clean before create** - Always start from updated main
3. **Commit frequently** - Small commits are easier to merge
4. **Pull before push** - Get latest changes to avoid conflicts
5. **Use descriptive branches** - `epic/feature-name` not `feature`

## Common Issues

### Branch Already Exists
```bash
# Delete old branch first
git branch -D epic/{name}
git push origin --delete epic/{name}
# Then create new one
```

### Cannot Push Branch
```bash
# Check if branch exists remotely
git ls-remote origin epic/{name}

# Push with upstream
git push -u origin epic/{name}
```

### Merge Conflicts During Pull
```bash
# Stash changes if needed
git stash

# Pull and rebase
git pull --rebase origin epic/{name}

# Restore changes
git stash pop
```

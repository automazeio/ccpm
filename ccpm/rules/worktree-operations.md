# Worktree Operations

Git worktrees enable parallel development by allowing multiple working directories for the same repository.

## Creating Worktrees

Always create worktrees from a clean main branch:
```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Create worktree for epic
git worktree add ../epic-{name} -b epic/{name}
```

The worktree will be created as a sibling directory to maintain clean separation.

## Working in Worktrees

### Agent Commits
- Agents commit directly to the worktree
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### File Operations
```bash
# Working directory is the worktree
cd ../epic-{name}

# Normal git operations work
git add {files}
git commit -m "Issue #{number}: {change}"

# View worktree status
git status
```

## Parallel Work in Same Worktree

Multiple agents can work in the same worktree if they touch different files:
```bash
# Agent A works on API
git add src/api/*
git commit -m "Issue #1234: Add user endpoints"

# Agent B works on UI (no conflict!)
git add src/ui/*
git commit -m "Issue #1235: Add dashboard component"
```

## Merging Worktrees

When epic is complete, merge back to main:
```bash
# From main repository (not worktree)
cd {main-repo}
git checkout main
git pull origin main

# Merge epic branch
git merge epic/{name}

# If successful, clean up
git worktree remove ../epic-{name}
git branch -d epic/{name}
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

## Worktree Management

### List Active Worktrees
```bash
git worktree list
```

### Remove Stale Worktree
```bash
# If worktree directory was deleted
git worktree prune

# Force remove worktree
git worktree remove --force ../epic-{name}
```

### Check Worktree Status
```bash
# From main repo
cd ../epic-{name} && git status && cd -
```

## Best Practices

1. **One worktree per epic** - Not per issue
2. **Clean before create** - Always start from updated main
3. **Commit frequently** - Small commits are easier to merge
4. **Delete after merge** - Don't leave stale worktrees
5. **Use descriptive branches** - `epic/feature-name` not `feature`

## Common Issues

### Worktree Already Exists
```bash
# Remove old worktree first
git worktree remove ../epic-{name}
# Then create new one
```

### Branch Already Exists
```bash
# Delete old branch
git branch -D epic/{name}
# Or use existing branch
git worktree add ../epic-{name} epic/{name}
```

### Cannot Remove Worktree
```bash
# Force removal
git worktree remove --force ../epic-{name}
# Clean up references
git worktree prune
```
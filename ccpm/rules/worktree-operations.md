# Worktree Operations

Git worktrees enable parallel development by allowing multiple working directories for the same repository.

## Creating Worktrees

Create worktrees from a clean, up-to-date main branch:
```bash
git checkout main
git pull origin main

git worktree add ../epic-{name} -b epic/{name}
```

The worktree is created as a sibling directory to maintain clean separation.

## Working in Worktrees

### Agent Commits
- Commit directly to the worktree
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### File Operations
```bash
# Working directory is the worktree
cd ../epic-{name}

git add {files}
git commit -m "Issue #{number}: {change}"

git status
```

## Parallel Work in Same Worktree

Multiple agents can work in the same worktree when they touch different files:
```bash
# Agent A works on API
git add src/api/*
git commit -m "Issue #1234: Add user endpoints"

# Agent B works on UI — no conflict
git add src/ui/*
git commit -m "Issue #1235: Add dashboard component"
```

## Merging Worktrees

When an epic is complete, merge back to main from the main repository (not the worktree):
```bash
cd {main-repo}
git checkout main
git pull origin main

git merge epic/{name}

# After successful merge, clean up
git worktree remove ../epic-{name}
git branch -d epic/{name}
```

## Handling Conflicts

```bash
git status

# Human resolves conflicts, then continue
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
# If worktree directory was deleted externally
git worktree prune

# Force remove worktree
git worktree remove --force ../epic-{name}
```

### Check Worktree Status
```bash
cd ../epic-{name} && git status && cd -
```

## Best Practices

1. **One worktree per epic** — Not per issue
2. **Clean before create** — Start from updated main
3. **Commit frequently** — Small commits are easier to merge
4. **Delete after merge** — Do not leave stale worktrees
5. **Use descriptive branches** — `epic/feature-name` not `feature`

## Common Issues

### Worktree Already Exists
```bash
git worktree remove ../epic-{name}
# Then create new one
```

### Branch Already Exists
```bash
git branch -D epic/{name}
# Or use existing branch
git worktree add ../epic-{name} epic/{name}
```

### Cannot Remove Worktree
```bash
git worktree remove --force ../epic-{name}
git worktree prune
```

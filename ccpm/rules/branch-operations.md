# Branch Operations

Git branches enable parallel development by allowing multiple developers to work on the same repository with isolated changes.

## Creating Branches

Create branches from a clean, up-to-date main branch:
```bash
git checkout main
git pull origin main

git checkout -b epic/{name}
git push -u origin epic/{name}
```

## Working in Branches

### Agent Commits
- Commit directly to the branch
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### File Operations
```bash
# Normal git operations work
git add {files}
git commit -m "Issue #{number}: {change}"

git status
git log --oneline -5
```

## Parallel Work in Same Branch

Multiple agents can work in the same branch when coordinating file access:
```bash
# Agent A works on API
git add src/api/*
git commit -m "Issue #1234: Add user endpoints"

# Agent B works on UI — pull latest before committing
git pull origin epic/{name}
git add src/ui/*
git commit -m "Issue #1235: Add dashboard component"
```

## Merging Branches

When an epic is complete, merge back to main:
```bash
git checkout main
git pull origin main

git merge epic/{name}

# After successful merge, clean up
git branch -d epic/{name}
git push origin --delete epic/{name}
```

## Handling Conflicts

```bash
# Conflicts will be shown
git status

# Human resolves conflicts, then continue
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
git branch -d epic/{name}
git push origin --delete epic/{name}
```

### Check Branch Status
```bash
git branch -v
git log --oneline main..epic/{name}
```

## Best Practices

1. **One branch per epic** — Not per issue
2. **Clean before create** — Start from updated main
3. **Commit frequently** — Small commits are easier to merge
4. **Pull before push** — Get latest changes to avoid conflicts
5. **Use descriptive branches** — `epic/feature-name` not `feature`

## Common Issues

### Branch Already Exists
```bash
git branch -D epic/{name}
git push origin --delete epic/{name}
# Then create new one
```

### Cannot Push Branch
```bash
# Check if branch exists remotely
git ls-remote origin epic/{name}

git push -u origin epic/{name}
```

### Merge Conflicts During Pull
```bash
git stash
git pull --rebase origin epic/{name}
git stash pop
```

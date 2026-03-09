---
allowed-tools: Bash(bash .claude/scripts/pm/ccpm-commit.sh *)
---

# CCPM Commit

Commits changes to the ccpm submodule and updates the parent project's pointer.

## Usage

```
/pm:ccpm-commit "Add new skill command"
/pm:ccpm-commit                          # Uses default message "Update ccpm"
```

## What It Does

1. **Commits in submodule** - Stages and commits all changes in `.claude/ccpm/`
2. **Pushes to origin** - Pushes the commit to the ccpm repository
3. **Updates parent** - Commits the updated submodule pointer in your project

## Workflow

```bash
# 1. Create/edit a skill
# Edit .claude/ccpm/ccpm/commands/pm/my-skill.md

# 2. Commit and push
/pm:ccpm-commit "Add my-skill command"

# 3. Push your project (if desired)
git push
```

## Requirements

- ccpm must be set up as a submodule (`/pm:ccpm-pull`)
- You must have push access to the ccpm repository

Output:
!bash .claude/scripts/pm/ccpm-commit.sh "$1"

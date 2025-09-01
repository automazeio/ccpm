---
allowed-tools: Read, LS
---

# Epic Oneshot

Decompose epic into tasks and sync to GitHub in one operation.

## Usage
```
/pm:epic-oneshot <feature_name>
```

## Instructions

### 1. Validate Prerequisites

Check that epic exists and hasn't been processed:
```bash
# Epic must exist
test -f .claude/epics/$ARGUMENTS/epic.md || echo "❌ Epic not found. Run: /pm:prd-parse $ARGUMENTS"

# Check for existing tasks
if ls .claude/epics/$ARGUMENTS/[0-9]*.md 2>/dev/null | grep -q .; then
  echo "⚠️ Tasks already exist. This will create duplicates."
  echo "Delete existing tasks or use /pm:epic-sync instead."
  exit 1
fi

# Check if already synced
if grep -q "github:" .claude/epics/$ARGUMENTS/epic.md; then
  echo "⚠️ Epic already synced to GitHub."
  echo "Use /pm:epic-sync to update."
  exit 1
fi
```

### 2. Ensure GitHub Labels

Set up all required labels before creating issues:
```bash
echo "🏷️  Ensuring GitHub labels..."

# Source the label utility script
if [[ -f "$(dirname "$0")/../scripts/pm/labels-ensure.sh" ]]; then
    source "$(dirname "$0")/../scripts/pm/labels-ensure.sh"
elif [[ -f ".claude/scripts/pm/labels-ensure.sh" ]]; then
    source ".claude/scripts/pm/labels-ensure.sh"
else
    echo "❌ Label utility script not found"
    echo "Expected at: .claude/scripts/pm/labels-ensure.sh"
    exit 1
fi

# Ensure all standard CCPM labels exist
echo "Setting up standard labels..."
ensure_standard_labels

# Create epic-specific label
echo "Setting up epic-specific label..."
ensure_epic_label "$ARGUMENTS"

echo "✅ All labels are ready"
echo ""
```

### 3. Execute Decompose

Simply run the decompose command:
```
Running: /pm:epic-decompose $ARGUMENTS
```

This will:
- Read the epic
- Create task files (using parallel agents if appropriate)
- Update epic with task summary

### 4. Execute Sync

Immediately follow with sync:
```
Running: /pm:epic-sync $ARGUMENTS
```

This will:
- Create epic issue on GitHub
- Create sub-issues (using parallel agents if appropriate)
- Rename task files to issue IDs
- Create worktree

### 5. Output

```
🚀 Epic Oneshot Complete: $ARGUMENTS

Step 1: Label Setup ✓
  - Standard labels ensured
  - Epic-specific label: epic:$ARGUMENTS
  
Step 2: Decomposition ✓
  - Tasks created: {count}
  
Step 3: GitHub Sync ✓
  - Epic: #{number}
  - Sub-issues created: {count}
  - Worktree: ../epic-$ARGUMENTS

Ready for development!
  Start work: /pm:epic-start $ARGUMENTS
  Or single task: /pm:issue-start {task_number}
```

## Important Notes

This is simply a convenience wrapper that runs:
1. Label preflight setup (ensures GitHub labels exist)
2. `/pm:epic-decompose` 
3. `/pm:epic-sync`

The label setup happens first to ensure all standard CCPM labels and the epic-specific label exist before any issues are created. Both decompose and sync commands handle their own error checking, parallel execution, and validation. This command just orchestrates them in sequence with proper label setup.

Use this when you're confident the epic is ready and want to go from epic to GitHub issues in one step.
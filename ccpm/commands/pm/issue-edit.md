---
allowed-tools: Bash, Read, Write, LS
---

# Issue Edit

Edit issue details locally and on GitHub.

## Usage
```
/pm:issue-edit <issue_number>
```

## Instructions

### 1. Get Current Issue State

```bash
# Get from GitHub
gh issue view $ARGUMENTS --json title,body,labels

# Find local task file
# Search for file with github:.*issues/$ARGUMENTS
```

### 2. Interactive Edit

Ask user what to edit:
- Title
- Description/Body
- Labels
- Acceptance criteria (local only)
- Priority/Size (local only)

### 3. Update Local File

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update task file with changes:
- Update frontmatter `name` if title changed
- Update body content if description changed
- Update `updated` field with current datetime

### 4. Update GitHub

If title changed:
```bash
gh issue edit $ARGUMENTS --title "{new_title}"
```

If body changed:
```bash
# Strip frontmatter from updated task file
sed '1,/^---$/d; 1,/^---$/d' {updated_task_file} > /tmp/updated-body.md

# Validate body has meaningful content
source .claude/scripts/utils.sh
min_length=$(get_min_content_length "edit:issue-$ARGUMENTS")
validate_body_file_has_content "/tmp/updated-body.md" "edit:issue-$ARGUMENTS" "$min_length"

# Update issue
gh issue edit $ARGUMENTS --body-file /tmp/updated-body.md
```

If labels changed:
```bash
# Ensure labels exist
for label in {new_labels}; do
  gh label create "$label" --force 2>/dev/null || true
done
gh issue edit $ARGUMENTS --add-label "{new_labels}"
gh issue edit $ARGUMENTS --remove-label "{removed_labels}"
```

### 5. Output

```
✅ Updated issue #$ARGUMENTS
  Changes:
    {list_of_changes_made}
  
Synced to GitHub: ✅
```

## Important Notes

Always update local first, then GitHub.
Preserve frontmatter fields not being edited.
Follow `/rules/frontmatter-operations.md`.
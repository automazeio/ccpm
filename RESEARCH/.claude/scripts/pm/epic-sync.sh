#!/bin/bash
# Epic Sync Script - Creates GitHub issues for epic tasks

EPIC_NAME="$1"
# Use relative path from current working directory
EPIC_DIR=".claude/epics/$EPIC_NAME"
# Derive repo from git remote origin
REPO=$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||' | sed 's|\.git$||')

if [ -z "$REPO" ]; then
  echo "Error: No git remote origin configured"
  exit 1
fi

if [ -z "$EPIC_NAME" ]; then
  echo "Usage: epic-sync.sh <epic_name>"
  exit 1
fi

if [ ! -f "$EPIC_DIR/epic.md" ]; then
  echo "Epic not found: $EPIC_DIR/epic.md"
  exit 1
fi

# Check if epic issue exists
EPIC_NUM=$(gh issue list --repo "$REPO" --search "Epic: $EPIC_NAME" --state open --limit 1 | awk '{print $1}')
if [ -z "$EPIC_NUM" ]; then
  echo "Creating epic issue..."
  sed '1,/^---$/d; 1,/^---$/d' "$EPIC_DIR/epic.md" > /tmp/epic-body.md
  EPIC_URL=$(gh issue create --repo "$REPO" --title "Epic: $EPIC_NAME" --body-file /tmp/epic-body.md --label "epic,feature" 2>&1 | tail -1)
  EPIC_NUM=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
  echo "Created epic #$EPIC_NUM"
else
  echo "Using existing epic #$EPIC_NUM"
fi

# Create task issues
rm -f /tmp/task-mapping.txt
for TASK_FILE in "$EPIC_DIR"/00[0-9].md; do
  [ -f "$TASK_FILE" ] || continue
  
  TASK_NAME=$(grep '^name:' "$TASK_FILE" | sed 's/^name: *//')
  sed '1,/^---$/d; 1,/^---$/d' "$TASK_FILE" > /tmp/task-body.md
  
  echo "Creating task: $TASK_NAME..."
  TASK_URL=$(gh issue create --repo "$REPO" --title "$TASK_NAME" --body-file /tmp/task-body.md --label "task,epic:$EPIC_NAME" 2>&1 | tail -1)
  TASK_NUM=$(echo "$TASK_URL" | grep -oE '[0-9]+$')
  
  if [ -n "$TASK_NUM" ]; then
    echo "$TASK_FILE:$TASK_NUM" >> /tmp/task-mapping.txt
    echo "  Created #$TASK_NUM"
  else
    echo "  Failed to create task"
  fi
done

# Rename files and update references
if [ -f /tmp/task-mapping.txt ]; then
  echo "Renaming task files..."
  while IFS=: read -r OLD_FILE NEW_NUM; do
    NEW_FILE="$EPIC_DIR/${NEW_NUM}.md"
    if [ "$OLD_FILE" != "$NEW_FILE" ]; then
      mv "$OLD_FILE" "$NEW_FILE"
      # Update github field
      sed -i "s|^github:.*|github: https://github.com/$REPO/issues/$NEW_NUM|" "$NEW_FILE"
      echo "  $(basename $OLD_FILE) -> $(basename $NEW_FILE)"
    fi
  done < /tmp/task-mapping.txt
fi

# Update epic frontmatter
sed -i "s|^github:.*|github: https://github.com/$REPO/issues/$EPIC_NUM|" "$EPIC_DIR/epic.md"

# Create mapping file
cat > "$EPIC_DIR/github-mapping.md" << EOF
# GitHub Issue Mapping

Epic: #$EPIC_NUM - https://github.com/$REPO/issues/$EPIC_NUM

Tasks:
EOF

for TASK_FILE in "$EPIC_DIR"/[0-9]*.md; do
  [ -f "$TASK_FILE" ] || continue
  ISSUE_NUM=$(basename "$TASK_FILE" .md)
  TASK_NAME=$(grep '^name:' "$TASK_FILE" | sed 's/^name: *//')
  echo "- #$ISSUE_NUM: $TASK_NAME" >> "$EPIC_DIR/github-mapping.md"
done

echo "" >> "$EPIC_DIR/github-mapping.md"
echo "Synced: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$EPIC_DIR/github-mapping.md"

echo ""
echo "Synced to GitHub:"
echo "  Epic: #$EPIC_NUM"
echo "  Tasks: $(wc -l < /tmp/task-mapping.txt 2>/dev/null || echo 0)"

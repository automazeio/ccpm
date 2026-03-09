#!/bin/bash
# CCPM Commit - Commit changes to ccpm submodule and update parent pointer
#
# This script handles the bidirectional workflow:
# 1. Commits changes made inside .claude/ccpm/ to the ccpm repo
# 2. Pushes to origin
# 3. Updates the parent project's submodule pointer
#
# Usage:
#   /pm:ccpm-commit "Add new feature"
#   /pm:ccpm-commit                      # Uses default message

set -e

MSG="${1:-Update ccpm}"
SUBMODULE_PATH=".claude/ccpm"

echo "CCPM Commit"
echo "==========="
echo ""

# --- Validation ---

if [ ! -d ".git" ]; then
    echo "ERROR: Not a git repository"
    exit 1
fi

if [ ! -d "$SUBMODULE_PATH/.git" ] && [ ! -f "$SUBMODULE_PATH/.git" ]; then
    echo "ERROR: ccpm submodule not found at $SUBMODULE_PATH"
    echo "Run /pm:ccpm-pull first to set up the submodule"
    exit 1
fi

# --- Step 1: Commit in submodule ---

echo "Step 1: Committing in ccpm submodule..."
echo ""

cd "$SUBMODULE_PATH"

# Check for changes
if git diff --quiet && git diff --cached --quiet; then
    # Check for untracked files
    if [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo "No changes to commit in ccpm submodule"
        cd - > /dev/null
        exit 0
    fi
fi

# Show what will be committed
echo "Changes to commit:"
git status --short
echo ""

# Stage all changes
git add -A

# Commit
git commit -m "$MSG" || {
    echo "Nothing to commit (maybe already committed?)"
    cd - > /dev/null
    exit 0
}

echo ""
echo "Committed: $MSG"

# --- Step 2: Push to origin ---

echo ""
echo "Step 2: Pushing to ccpm origin..."

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)

git push origin "$BRANCH" || {
    echo ""
    echo "WARNING: Push failed. You may need to:"
    echo "  cd $SUBMODULE_PATH"
    echo "  git push origin $BRANCH"
    echo ""
    echo "Continuing to update parent pointer..."
}

# Get the commit hash for reference
COMMIT_HASH=$(git rev-parse --short HEAD)

cd - > /dev/null

# --- Step 3: Update parent pointer ---

echo ""
echo "Step 3: Updating parent project's submodule pointer..."

git add "$SUBMODULE_PATH"

# Check if there's actually a change to commit
if git diff --cached --quiet; then
    echo "Parent pointer already up to date"
else
    git commit -m "ccpm: $MSG" -m "Updated to commit $COMMIT_HASH"
    echo "Parent pointer updated"
fi

# --- Summary ---

echo ""
echo "==========="
echo "Done!"
echo ""
echo "ccpm commit:  $COMMIT_HASH"
echo "Message:      $MSG"
echo ""
echo "To push parent project: git push"

exit 0

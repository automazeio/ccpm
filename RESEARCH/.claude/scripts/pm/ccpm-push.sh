#!/bin/bash
# CCPM Push - Push local customizations to canonical ccpm repo via PR

set -e

PR_TITLE_SUFFIX="$1"

echo "CCPM Push - Contributing to canonical repository"
echo "================================================="
echo ""

# Validation
if [ -z "$CCPM_SOURCE_REPO" ]; then
    echo "ERROR: CCPM_SOURCE_REPO environment variable not set"
    exit 1
fi

if [ ! -d "$CCPM_SOURCE_REPO" ]; then
    echo "ERROR: CCPM_SOURCE_REPO does not exist: $CCPM_SOURCE_REPO"
    exit 1
fi

if [ ! -d "$CCPM_SOURCE_REPO/.git" ]; then
    echo "ERROR: CCPM_SOURCE_REPO is not a git repository"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) not found"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "ERROR: GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

if [ ! -d ".claude" ]; then
    echo "ERROR: No .claude directory in current project"
    exit 1
fi

SOURCE_BASE="$CCPM_SOURCE_REPO/ccpm"
LOCAL_BASE=".claude"

# Directories to sync
SYNC_DIRS=("commands" "scripts" "rules" "agents" "hooks" "schemas" "services" "testing" "templates" "k8s")
SYNC_FILES=("ccpm.config")

# Get project name
get_project_name() {
    if git remote get-url origin &> /dev/null; then
        git remote get-url origin | sed 's|.*[:/]||' | sed 's|\.git$||'
    else
        basename "$(pwd)"
    fi
}

PROJECT_NAME=$(get_project_name | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
BRANCH_NAME="contrib/${PROJECT_NAME}"

echo "Project: $PROJECT_NAME"
echo "Branch:  $BRANCH_NAME"
echo ""

# Update canonical repo first
echo "Updating canonical CCPM repo..."
(
    cd "$CCPM_SOURCE_REPO"
    MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || MAIN_BRANCH="main"
    git checkout "$MAIN_BRANCH" 2>/dev/null || true
    git pull origin "$MAIN_BRANCH" 2>/dev/null || true
) || echo "Warning: Could not update canonical repo"
echo ""

# Analyze differences
echo "Analyzing differences..."

new_files=()
modified_files=()
deleted_files=()

# Find new and modified files (local -> source)
for dir in "${SYNC_DIRS[@]}"; do
    local_dir="$LOCAL_BASE/$dir"
    [ ! -d "$local_dir" ] && continue

    while IFS= read -r -d '' local_file; do
        rel_path="${local_file#$LOCAL_BASE/}"
        source_file="$SOURCE_BASE/$rel_path"

        if [ ! -f "$source_file" ]; then
            new_files+=("$rel_path")
        elif ! diff -q "$local_file" "$source_file" > /dev/null 2>&1; then
            modified_files+=("$rel_path")
        fi
    done < <(find "$local_dir" -type f -print0 2>/dev/null)
done

# Find deleted files (exist in source but not locally)
for dir in "${SYNC_DIRS[@]}"; do
    source_dir="$SOURCE_BASE/$dir"
    [ ! -d "$source_dir" ] && continue

    while IFS= read -r -d '' source_file; do
        rel_path="${source_file#$SOURCE_BASE/}"
        local_file="$LOCAL_BASE/$rel_path"

        if [ ! -f "$local_file" ]; then
            deleted_files+=("$rel_path")
        fi
    done < <(find "$source_dir" -type f -print0 2>/dev/null)
done

for file in "${SYNC_FILES[@]}"; do
    if [ -f "$LOCAL_BASE/$file" ]; then
        if [ ! -f "$SOURCE_BASE/$file" ]; then
            new_files+=("$file")
        elif ! diff -q "$LOCAL_BASE/$file" "$SOURCE_BASE/$file" > /dev/null 2>&1; then
            modified_files+=("$file")
        fi
    elif [ -f "$SOURCE_BASE/$file" ]; then
        # File exists in source but not locally - deleted
        deleted_files+=("$file")
    fi
done

echo ""
echo "New files:      ${#new_files[@]}"
echo "Modified files: ${#modified_files[@]}"
echo "Deleted files:  ${#deleted_files[@]}"

if [ ${#new_files[@]} -eq 0 ] && [ ${#modified_files[@]} -eq 0 ] && [ ${#deleted_files[@]} -eq 0 ]; then
    echo ""
    echo "No differences found. Nothing to push."
    exit 0
fi

echo ""
[ ${#new_files[@]} -gt 0 ] && printf '  + %s\n' "${new_files[@]}"
[ ${#modified_files[@]} -gt 0 ] && printf '  ~ %s\n' "${modified_files[@]}"
[ ${#deleted_files[@]} -gt 0 ] && printf '  - %s\n' "${deleted_files[@]}"

# Save current directory
ORIGINAL_DIR=$(pwd)

# Work in canonical repo
cd "$CCPM_SOURCE_REPO"

# Get main branch name
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || MAIN_BRANCH="main"

# Update main
echo ""
echo "Updating $MAIN_BRANCH..."
git checkout "$MAIN_BRANCH" 2>/dev/null
git pull origin "$MAIN_BRANCH" 2>/dev/null || true

# Check if branch exists (auto-merge to existing)
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch $BRANCH_NAME exists, updating..."
    git checkout "$BRANCH_NAME"
    git merge "$MAIN_BRANCH" -m "Merge $MAIN_BRANCH" 2>/dev/null || true
else
    echo "Creating branch $BRANCH_NAME..."
    git checkout -b "$BRANCH_NAME"
fi

# Copy files
echo ""
echo "Copying files..."

for rel_path in "${new_files[@]}"; do
    src="$ORIGINAL_DIR/$LOCAL_BASE/$rel_path"
    dst="$SOURCE_BASE/$rel_path"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  + $rel_path"
done

for rel_path in "${modified_files[@]}"; do
    src="$ORIGINAL_DIR/$LOCAL_BASE/$rel_path"
    dst="$SOURCE_BASE/$rel_path"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  ~ $rel_path"
done

for rel_path in "${deleted_files[@]}"; do
    dst="$SOURCE_BASE/$rel_path"
    if [ -f "$dst" ]; then
        rm "$dst"
        echo "  - $rel_path"
    fi
done

# Make scripts executable
find "$SOURCE_BASE/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Commit
echo ""
echo "Committing..."

git add ccpm/

COMMIT_MSG="feat: contributions from $PROJECT_NAME"
[ -n "$PR_TITLE_SUFFIX" ] && COMMIT_MSG="feat: $PR_TITLE_SUFFIX (from $PROJECT_NAME)"

if git diff --cached --quiet; then
    echo "No changes to commit"
else
    git commit -m "$COMMIT_MSG" -m "New: ${#new_files[@]}, Modified: ${#modified_files[@]}, Deleted: ${#deleted_files[@]}"
fi

# Push
echo ""
echo "Pushing..."
git push -u origin "$BRANCH_NAME" 2>&1

# Create or update PR
echo ""
echo "Creating/updating PR..."

PR_TITLE="[contrib] $PROJECT_NAME${PR_TITLE_SUFFIX:+: $PR_TITLE_SUFFIX}"

# Build file list
FILE_LIST=""
for f in "${new_files[@]}"; do FILE_LIST="${FILE_LIST}- \`${f}\` (new)"$'\n'; done
for f in "${modified_files[@]}"; do FILE_LIST="${FILE_LIST}- \`${f}\` (modified)"$'\n'; done
for f in "${deleted_files[@]}"; do FILE_LIST="${FILE_LIST}- \`${f}\` (deleted)"$'\n'; done

PR_BODY="## Contributions from $PROJECT_NAME

**New:** ${#new_files[@]} | **Modified:** ${#modified_files[@]} | **Deleted:** ${#deleted_files[@]}

### Files
${FILE_LIST}
---
*Created by /pm:ccpm-push*"

# Check if PR exists for this branch
EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --state open --json number,url -q '.[0]' 2>/dev/null)

if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
    PR_NUMBER=$(echo "$EXISTING_PR" | jq -r '.number')
    PR_URL=$(echo "$EXISTING_PR" | jq -r '.url')
    echo "Updating existing PR #$PR_NUMBER..."
    # Update PR body with latest file list
    gh pr edit "$PR_NUMBER" --body "$PR_BODY" 2>/dev/null || true
else
    echo "Creating new PR..."
    # Create PR - use || true to prevent set -e from exiting
    PR_URL=$(gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --base "$MAIN_BRANCH" \
        --head "$BRANCH_NAME" 2>&1) || true

    # Extract URL from output if present
    if echo "$PR_URL" | grep -q "https://"; then
        PR_URL=$(echo "$PR_URL" | grep -o 'https://github.com[^ ]*' | head -1)
    else
        # PR creation may have failed - show the error
        echo "⚠️  PR creation returned: $PR_URL"
        # Try to get PR URL if it was created anyway
        PR_URL=$(gh pr view --json url -q .url 2>/dev/null || echo "")
        if [ -z "$PR_URL" ]; then
            echo "PR not created. You may need to create it manually at:"
            echo "  https://github.com/elysenko/ccpm/pull/new/$BRANCH_NAME"
            PR_URL="(manual creation needed)"
        fi
    fi
fi

# Get PR number for merge operations
PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")

# Auto-merge the PR
MERGE_STATUS=""
if [ -n "$PR_NUMBER" ]; then
    echo ""
    echo "Attempting to merge PR #$PR_NUMBER..."

    # Capture merge output to show actual errors
    MERGE_OUTPUT=$(gh pr merge "$PR_NUMBER" --squash --delete-branch 2>&1) && MERGE_RC=$? || MERGE_RC=$?

    if [ $MERGE_RC -eq 0 ]; then
        MERGE_STATUS="✅ merged and branch deleted"
    else
        echo "  Direct merge failed: $MERGE_OUTPUT"

        # Try auto-merge (requires repo setting enabled)
        echo "  Trying auto-merge..."
        AUTO_OUTPUT=$(gh pr merge "$PR_NUMBER" --squash --auto 2>&1) && AUTO_RC=$? || AUTO_RC=$?

        if [ $AUTO_RC -eq 0 ]; then
            MERGE_STATUS="⏳ auto-merge enabled (will merge when checks pass)"
        else
            # Check if it's a permission issue
            if echo "$MERGE_OUTPUT $AUTO_OUTPUT" | grep -qi "permission\|authorized\|403\|pull request is not mergeable"; then
                MERGE_STATUS="⚠️  no merge permission (need collaborator access or repo owner approval)"
            elif echo "$MERGE_OUTPUT $AUTO_OUTPUT" | grep -qi "review\|approval"; then
                MERGE_STATUS="⚠️  requires review approval before merge"
            elif echo "$MERGE_OUTPUT $AUTO_OUTPUT" | grep -qi "checks\|status"; then
                MERGE_STATUS="⚠️  waiting for status checks to pass"
            else
                MERGE_STATUS="⚠️  merge failed: $AUTO_OUTPUT"
            fi
        fi
    fi
else
    echo ""
    echo "⚠️  Could not get PR number - skipping merge attempt"
    MERGE_STATUS="⚠️  PR number not found"
fi

# Note: Removed rsync to .claude/ - submodule mode uses symlinks instead
# Legacy file-copy users should run /pm:ccpm-pull after pushing

# Return to original directory
cd "$ORIGINAL_DIR"

echo ""
echo "================================================="
echo "Done!"
echo ""
echo "Branch: $BRANCH_NAME"
echo "PR:     $PR_URL"
[ -n "$MERGE_STATUS" ] && echo "Status: $MERGE_STATUS"

exit 0

#!/bin/bash
# CCPM Pull Legacy - Sync framework files from canonical ccpm repo to local .claude/
#
# This is the original file-copy approach. Use this if submodules don't work
# for your environment.
#
# Usage:
#   CCPM_LEGACY=1 /pm:ccpm-pull
#   # or directly:
#   bash .claude/scripts/pm/ccpm-pull-legacy.sh

set -e

echo "CCPM Pull (Legacy File-Copy Mode)"
echo "=================================="
echo ""

# Validation
if [ -z "$CCPM_SOURCE_REPO" ]; then
    echo "ERROR: CCPM_SOURCE_REPO environment variable not set"
    echo ""
    echo "Set it to the path of your canonical ccpm repository:"
    echo "  export CCPM_SOURCE_REPO=/path/to/ccpm/repo"
    exit 1
fi

if [ ! -d "$CCPM_SOURCE_REPO" ]; then
    echo "ERROR: CCPM_SOURCE_REPO does not exist: $CCPM_SOURCE_REPO"
    exit 1
fi

# Check for canonical ccpm/ directory (preferred) or fall back to .claude/
if [ -d "$CCPM_SOURCE_REPO/ccpm" ]; then
    SOURCE_BASE="$CCPM_SOURCE_REPO/ccpm"
elif [ -d "$CCPM_SOURCE_REPO/.claude" ]; then
    SOURCE_BASE="$CCPM_SOURCE_REPO/.claude"
else
    echo "ERROR: Invalid ccpm repo structure (missing ccpm/ or .claude/ folder)"
    exit 1
fi

LOCAL_BASE=".claude"

echo "Source: $SOURCE_BASE (canonical)"
echo "Local:  $LOCAL_BASE"
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

# Directories to sync (framework components)
SYNC_DIRS=("commands" "scripts" "rules" "agents" "hooks" "schemas" "services" "testing" "templates" "k8s")

# Files to sync
SYNC_FILES=("ccpm.config")

# Stats
copied_new=0
copied_updated=0
backed_up=0
skipped=0

# Backup function
backup_file() {
    local file="$1"
    local backup_dir="$LOCAL_BASE/.backups/$(date +%Y%m%d_%H%M%S)"
    local rel_path="${file#$LOCAL_BASE/}"
    local backup_path="$backup_dir/$rel_path"

    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    backed_up=$((backed_up + 1))
}

# Sync single file
sync_file() {
    local src="$1"
    local dst="$2"
    local rel_path="${dst#$LOCAL_BASE/}"

    if [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  + $rel_path"
        copied_new=$((copied_new + 1))
    elif ! diff -q "$src" "$dst" > /dev/null 2>&1; then
        backup_file "$dst"
        cp "$src" "$dst"
        echo "  ~ $rel_path"
        copied_updated=$((copied_updated + 1))
    else
        skipped=$((skipped + 1))
    fi
}

# Sync directories
for dir in "${SYNC_DIRS[@]}"; do
    src_dir="$SOURCE_BASE/$dir"
    dst_dir="$LOCAL_BASE/$dir"

    [ ! -d "$src_dir" ] && continue

    echo "Syncing $dir/..."

    while IFS= read -r -d '' src_file; do
        rel_path="${src_file#$src_dir/}"
        dst_file="$dst_dir/$rel_path"
        sync_file "$src_file" "$dst_file"
    done < <(find "$src_dir" -type f -print0)
done

# Sync individual files
echo ""
echo "Syncing files..."
for file in "${SYNC_FILES[@]}"; do
    [ -f "$SOURCE_BASE/$file" ] && sync_file "$SOURCE_BASE/$file" "$LOCAL_BASE/$file"
done

# Make scripts executable
find "$LOCAL_BASE/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Add .backups to .gitignore if not present
if [ -f ".gitignore" ]; then
    grep -q "^\.claude/\.backups" .gitignore 2>/dev/null || echo ".claude/.backups" >> .gitignore
elif [ -d ".git" ]; then
    echo ".claude/.backups" >> .gitignore
fi

# Summary
echo ""
echo "=================================="
echo "Done!"
echo ""
echo "  New files:     $copied_new"
echo "  Updated:       $copied_updated"
echo "  Backed up:     $backed_up"
echo "  Unchanged:     $skipped"

[ $backed_up -gt 0 ] && echo "" && echo "Backups: $LOCAL_BASE/.backups/"

exit 0

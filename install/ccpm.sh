#!/bin/bash

set -e

REPO_URL="https://github.com/automazeio/ccpm.git"
TARGET_DIR="$(pwd)"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Installing Claude Code PM..."
echo "Cloning repository to temporary directory..."

git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

# The repo has ccpm/ folder that should become .claude/
SOURCE_DIR="$TEMP_DIR/ccpm"

if [ -d "$TARGET_DIR/.claude" ]; then
    echo "Existing .claude directory detected."
    echo "Merging ccpm files into existing .claude directory..."

    # Copy directories - merge without overwriting existing files
    for dir in agents commands context prds rules scripts hooks; do
        if [ -d "$SOURCE_DIR/$dir" ]; then
            mkdir -p "$TARGET_DIR/.claude/$dir"
            # Use cp -n (no clobber) or rsync as fallback
            if cp -rn "$SOURCE_DIR/$dir/." "$TARGET_DIR/.claude/$dir/" 2>/dev/null; then
                :
            else
                # macOS cp might not support -n, use rsync
                rsync -a --ignore-existing "$SOURCE_DIR/$dir/" "$TARGET_DIR/.claude/$dir/" 2>/dev/null || \
                cp -r "$SOURCE_DIR/$dir/." "$TARGET_DIR/.claude/$dir/"
            fi
        fi
    done

    # Copy config files if they don't exist
    for file in ccpm.config settings.json.example settings.local.json; do
        if [ -f "$SOURCE_DIR/$file" ] && [ ! -f "$TARGET_DIR/.claude/$file" ]; then
            cp "$SOURCE_DIR/$file" "$TARGET_DIR/.claude/$file"
        fi
    done

    echo "Merge complete. Your existing customizations are preserved."
else
    echo "Creating new .claude directory..."
    mkdir -p "$TARGET_DIR/.claude"
    cp -r "$SOURCE_DIR/." "$TARGET_DIR/.claude/"
fi

# Create epics directory if it doesn't exist
mkdir -p "$TARGET_DIR/.claude/epics"

echo ""
echo "Claude Code PM installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run '/pm:init' in Claude Code to complete setup"
echo "  2. Copy relevant instructions from README.md to your CLAUDE.md"
echo ""

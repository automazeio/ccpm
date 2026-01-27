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

if [ -d "$TARGET_DIR/.claude" ]; then
    echo "Existing .claude directory detected."
    echo "Merging ccpm files into existing .claude directory..."

    # Backup existing CLAUDE.md if it exists and differs
    if [ -f "$TARGET_DIR/.claude/CLAUDE.md" ]; then
        if ! cmp -s "$TARGET_DIR/.claude/CLAUDE.md" "$TEMP_DIR/.claude/CLAUDE.md" 2>/dev/null; then
            echo "Backing up existing CLAUDE.md to CLAUDE.md.backup"
            cp "$TARGET_DIR/.claude/CLAUDE.md" "$TARGET_DIR/.claude/CLAUDE.md.backup"
        fi
    fi

    # Copy directories (agents, commands, context, prds, rules) - merge without overwriting existing files
    for dir in agents commands context prds rules; do
        if [ -d "$TEMP_DIR/.claude/$dir" ]; then
            mkdir -p "$TARGET_DIR/.claude/$dir"
            cp -rn "$TEMP_DIR/.claude/$dir/." "$TARGET_DIR/.claude/$dir/" 2>/dev/null || \
            rsync -a --ignore-existing "$TEMP_DIR/.claude/$dir/" "$TARGET_DIR/.claude/$dir/"
        fi
    done

    # Copy CLAUDE.md (overwrite with new version, backup already made)
    cp "$TEMP_DIR/.claude/CLAUDE.md" "$TARGET_DIR/.claude/CLAUDE.md"

    echo "Merge complete. Your existing customizations are preserved."
else
    echo "Creating new .claude directory..."
    cp -r "$TEMP_DIR/.claude" "$TARGET_DIR/.claude"
fi

# Create epics directory if it doesn't exist
mkdir -p "$TARGET_DIR/.claude/epics"

echo ""
echo "✓ Claude Code PM installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run '/pm:init' in Claude Code to complete setup"
echo "  2. Check .claude/CLAUDE.md for configuration options"
echo ""

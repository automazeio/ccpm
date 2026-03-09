#!/bin/bash
# ccpm-push-pull-all.sh - Push local changes then pull to all repos
#
# Combines ccpm-push and ccpm-pull-all-repos into a single operation.
# Useful for syncing changes across all projects after making local modifications.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "CCPM Push + Pull All"
echo "=============================================="
echo ""

# Step 1: Push local changes to canonical repo
echo "Step 1/2: Pushing changes to canonical repo..."
echo ""
bash "$SCRIPT_DIR/ccpm-push.sh" "$@"

echo ""
echo "=============================================="
echo ""

# Step 2: Pull changes to all repos
echo "Step 2/2: Pulling changes to all repos..."
echo ""
bash "$SCRIPT_DIR/ccpm-pull-all-repos.sh"

echo ""
echo "=============================================="
echo "✅ Push + Pull All complete"
echo "=============================================="

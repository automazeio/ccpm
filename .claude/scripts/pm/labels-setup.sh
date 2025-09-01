#!/bin/bash
# labels-setup.sh - Standalone command to set up all standard CCPM labels
#
# This script provides a manual way to initialize all standard GitHub labels
# for a repository. It sources the labels-ensure utility and provides
# a standalone command interface.

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Show help if requested
if [[ "${1:-}" == "--help" ]]; then
    cat <<EOF
labels-setup - Set up standard CCPM GitHub labels

USAGE:
    bash .claude/scripts/pm/labels-setup.sh [--help]

DESCRIPTION:
    Creates all standard CCPM labels in the current GitHub repository.
    This includes epic, task, feature, bug, and test-related labels
    with proper colors and descriptions.

LABELS CREATED:
    epic             - Epic issue containing multiple tasks (#7057ff)
    task             - Individual task within an epic (#0969da)
    feature          - New feature or enhancement (#0e8a16)
    bug              - Something isn't working (#d73a4a)
    test:not-written - Test specification exists but no code (#6e7781)
    test:written     - Test code exists but not verified (#fbca04)
    test:passing     - Test executes successfully (#0e8a16)
    test:failing     - Test currently failing (#d73a4a)
    test:flaky       - Test intermittently fails (#fb8500)

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - Must be run from within a Git repository
    - Repository must be connected to GitHub

EXIT CODES:
    0 - Success
    1 - Error (authentication, repository issues, etc.)
EOF
    exit 0
fi

# Check if we can find the labels-ensure utility
LABELS_ENSURE_SCRIPT=""

# Try relative path from the worktree first
if [[ -f "$SCRIPT_DIR/labels-ensure.sh" ]]; then
    LABELS_ENSURE_SCRIPT="$SCRIPT_DIR/labels-ensure.sh"
# Try the main repository path
elif [[ -f "$PROJECT_ROOT/../ccpm_enhanced/.claude/scripts/pm/labels-ensure.sh" ]]; then
    LABELS_ENSURE_SCRIPT="$PROJECT_ROOT/../ccpm_enhanced/.claude/scripts/pm/labels-ensure.sh"
# Try common locations
elif [[ -f "$PROJECT_ROOT/.claude/scripts/pm/labels-ensure.sh" ]]; then
    LABELS_ENSURE_SCRIPT="$PROJECT_ROOT/.claude/scripts/pm/labels-ensure.sh"
else
    echo "❌ Error: Cannot find labels-ensure.sh utility script"
    echo "   Expected locations:"
    echo "   - $SCRIPT_DIR/labels-ensure.sh"
    echo "   - $PROJECT_ROOT/.claude/scripts/pm/labels-ensure.sh"
    echo ""
    echo "   This script requires the labels-ensure.sh utility to function."
    exit 1
fi

echo "🏷️  Setting up CCPM labels..."
echo ""

# Source the labels-ensure utility
# shellcheck source=/dev/null
source "$LABELS_ENSURE_SCRIPT"

# Check GitHub CLI authentication
if ! check_gh_cli; then
    echo ""
    echo "❌ GitHub CLI authentication failed"
    echo "   Please run: gh auth login"
    exit 1
fi

echo ""
echo "📋 Repository: $(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo 'Unknown')"
echo ""

# Track statistics
created_count=0
existed_count=0
failed_count=0

# Process each standard label with nice output
# (STANDARD_LABELS and LABEL_DESCRIPTIONS are already defined in labels-ensure.sh)

# Process labels in a specific order for better UX
label_order=("epic" "task" "feature" "bug" "test:not-written" "test:written" "test:passing" "test:failing" "test:flaky")

# Temporarily disable set -e for the loop to handle individual failures gracefully
set +e

for label_name in "${label_order[@]}"; do
    printf "  %-18s " "$label_name"
    
    if check_label_exists "$label_name"; then
        echo "⏭️  Exists"
        ((existed_count++))
    else
        color="${STANDARD_LABELS[$label_name]}"
        description="${LABEL_DESCRIPTIONS[$label_name]}"
        
        if gh label create "$label_name" --color "$color" --description "$description" >/dev/null 2>&1; then
            echo "✅ Created"
            ((created_count++))
            # Invalidate cache after successful creation
            cache_file=$(get_cache_file)
            rm -f "$cache_file" 2>/dev/null || true
        else
            echo "❌ Failed"
            ((failed_count++))
        fi
    fi
done

# Re-enable set -e
set -e

echo ""
echo "📊 Summary: $created_count created, $existed_count already existed"

if [[ $failed_count -gt 0 ]]; then
    echo "⚠️  Warning: $failed_count labels failed to create"
    exit 1
fi

if [[ $created_count -gt 0 ]]; then
    echo "✅ Successfully initialized CCPM labels"
else
    echo "✅ All CCPM labels were already configured"
fi

echo ""
echo "🎉 Label setup complete! You can now use these labels in GitHub issues."
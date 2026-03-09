#!/bin/bash
# CCPM Pull All Repos - Sync framework files to all CCPM-enabled projects

set -e

echo "CCPM Pull All Repos"
echo "==================="
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

# Determine search paths
# Priority: 1) command line args, 2) PROJECTS_DIR env var, 3) common defaults
if [ $# -gt 0 ]; then
    SEARCH_PATHS=("$@")
else
    SEARCH_PATHS=()

    # Add PROJECTS_DIR if set
    [ -n "$PROJECTS_DIR" ] && [ -d "$PROJECTS_DIR" ] && SEARCH_PATHS+=("$PROJECTS_DIR")

    # Add common project locations
    [ -d "$HOME/projects" ] && SEARCH_PATHS+=("$HOME/projects")
    [ -d "$HOME/code" ] && SEARCH_PATHS+=("$HOME/code")
    [ -d "$HOME/dev" ] && SEARCH_PATHS+=("$HOME/dev")
    [ -d "$HOME/robert-projects" ] && SEARCH_PATHS+=("$HOME/robert-projects")

    # Current directory if nothing else
    [ ${#SEARCH_PATHS[@]} -eq 0 ] && SEARCH_PATHS+=(".")
fi

echo "Source: $CCPM_SOURCE_REPO"
echo "Search paths:"
for path in "${SEARCH_PATHS[@]}"; do
    echo "  - $path"
done
echo ""

# Find all CCPM-enabled projects
echo "Finding CCPM-enabled projects..."
ccpm_projects=()

for search_path in "${SEARCH_PATHS[@]}"; do
    while IFS= read -r -d '' claude_dir; do
        project_dir=$(dirname "$claude_dir")

        # Skip the source repo itself
        [ "$project_dir" = "$CCPM_SOURCE_REPO" ] && continue

        # Skip if inside node_modules or similar
        [[ "$project_dir" == *"/node_modules/"* ]] && continue
        [[ "$project_dir" == *"/.git/"* ]] && continue

        ccpm_projects+=("$project_dir")
    done < <(find "$search_path" -maxdepth 3 -type d -name ".claude" -print0 2>/dev/null)
done

# Remove duplicates
IFS=$'\n' ccpm_projects=($(printf '%s\n' "${ccpm_projects[@]}" | sort -u))
unset IFS

if [ ${#ccpm_projects[@]} -eq 0 ]; then
    echo "No CCPM-enabled projects found."
    echo ""
    echo "Make sure projects have a .claude/ directory."
    exit 0
fi

echo "Found ${#ccpm_projects[@]} project(s):"
for project in "${ccpm_projects[@]}"; do
    echo "  - $project"
done
echo ""

# Get the ccpm-pull script path
PULL_SCRIPT="$CCPM_SOURCE_REPO/ccpm/scripts/pm/ccpm-pull.sh"

if [ ! -f "$PULL_SCRIPT" ]; then
    # Try alternate location
    PULL_SCRIPT="$CCPM_SOURCE_REPO/.claude/scripts/pm/ccpm-pull.sh"
fi

if [ ! -f "$PULL_SCRIPT" ]; then
    echo "ERROR: Cannot find ccpm-pull.sh script"
    exit 1
fi

# Stats
success_count=0
failed_count=0
skipped_count=0
failed_projects=()

# Process each project
for project in "${ccpm_projects[@]}"; do
    project_name=$(basename "$project")
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Updating: $project_name"
    echo "Path: $project"
    echo ""

    # Change to project directory and run pull
    if cd "$project" 2>/dev/null; then
        if bash "$PULL_SCRIPT" 2>&1; then
            success_count=$((success_count + 1))
            echo ""
            echo "✅ $project_name updated"
        else
            failed_count=$((failed_count + 1))
            failed_projects+=("$project_name")
            echo ""
            echo "❌ $project_name failed"
        fi
    else
        skipped_count=$((skipped_count + 1))
        echo "⚠️  Cannot access $project"
    fi
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary"
echo "======="
echo ""
echo "  Projects found:   ${#ccpm_projects[@]}"
echo "  Updated:          $success_count"
echo "  Failed:           $failed_count"
echo "  Skipped:          $skipped_count"

if [ ${#failed_projects[@]} -gt 0 ]; then
    echo ""
    echo "Failed projects:"
    for fp in "${failed_projects[@]}"; do
        echo "  - $fp"
    done
fi

echo ""

[ $failed_count -eq 0 ] && exit 0 || exit 1

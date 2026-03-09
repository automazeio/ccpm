#!/bin/bash
# CCPM Pull - Initialize/update ccpm as git submodule with symlinks
#
# This script sets up ccpm as a git submodule at .claude/ccpm/ and creates
# symlinks so Claude discovers commands at .claude/commands/, etc.
#
# Usage:
#   /pm:ccpm-pull                    # Use default repo (automazeio/ccpm)
#   CCPM_REPO_URL=... /pm:ccpm-pull  # Use custom repo
#
# Environment variables:
#   CCPM_REPO_URL   - Git URL for ccpm repo (default: https://github.com/automazeio/ccpm.git)
#   CCPM_BRANCH     - Branch to track (default: main)
#   CCPM_LEGACY     - Set to "1" to use file-copy mode instead of submodules

set -e

# Configuration
CCPM_REPO_URL="${CCPM_REPO_URL:-https://github.com/automazeio/ccpm.git}"
CCPM_BRANCH="${CCPM_BRANCH:-main}"
SUBMODULE_PATH=".claude/ccpm"

# Directories to symlink (Claude discovers these)
SYMLINK_DIRS=("commands" "scripts" "rules" "agents" "hooks" "schemas" "templates" "services" "testing" "k8s")

# Project-specific directories (not symlinked, for local data)
LOCAL_DIRS=("prds" "epics" "local" ".backups")

echo "CCPM Pull (Submodule Mode)"
echo "=========================="
echo ""

# --- Validation ---

if [ ! -d ".git" ]; then
    echo "ERROR: Not a git repository"
    echo "Run: git init"
    exit 1
fi

# Check for legacy mode
if [ "$CCPM_LEGACY" = "1" ]; then
    echo "Legacy mode requested. Use ccpm-pull-legacy.sh instead."
    if [ -f ".claude/scripts/pm/ccpm-pull-legacy.sh" ]; then
        exec bash .claude/scripts/pm/ccpm-pull-legacy.sh
    else
        echo "ERROR: Legacy script not found"
        exit 1
    fi
fi

# --- Functions ---

init_submodule() {
    # Check if submodule already exists
    if [ -f "$SUBMODULE_PATH/.git" ] || [ -d "$SUBMODULE_PATH/.git" ]; then
        echo "Submodule already exists at $SUBMODULE_PATH"
        return 0
    fi

    # Check if path exists but isn't a submodule
    if [ -d "$SUBMODULE_PATH" ]; then
        echo "WARNING: $SUBMODULE_PATH exists but is not a submodule"
        echo "Backing up to ${SUBMODULE_PATH}.bak and reinitializing..."
        mv "$SUBMODULE_PATH" "${SUBMODULE_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Check if already in .gitmodules but directory missing
    if grep -q "path = $SUBMODULE_PATH" .gitmodules 2>/dev/null; then
        echo "Submodule registered but missing. Initializing..."
        git submodule update --init "$SUBMODULE_PATH"
        return 0
    fi

    echo "Adding ccpm as submodule..."
    echo "  URL:    $CCPM_REPO_URL"
    echo "  Branch: $CCPM_BRANCH"
    echo "  Path:   $SUBMODULE_PATH"
    echo ""

    mkdir -p "$(dirname "$SUBMODULE_PATH")"
    git submodule add -b "$CCPM_BRANCH" "$CCPM_REPO_URL" "$SUBMODULE_PATH"
}

update_submodule() {
    echo "Updating ccpm submodule..."
    git submodule update --init --recursive "$SUBMODULE_PATH"

    # Optionally update to latest on tracked branch
    echo "Fetching latest from $CCPM_BRANCH..."
    (
        cd "$SUBMODULE_PATH"
        git fetch origin "$CCPM_BRANCH"
        git checkout "$CCPM_BRANCH"
        git pull origin "$CCPM_BRANCH"
    ) || echo "WARNING: Could not update to latest (may need manual intervention)"
}

create_symlinks() {
    echo ""
    echo "Creating symlinks..."

    # Determine the source path inside the submodule
    # ccpm repo has structure: ccpm/commands/, ccpm/scripts/, etc.
    local source_base="ccpm/ccpm"

    if [ ! -d "$SUBMODULE_PATH/ccpm" ]; then
        # Fallback: maybe it's a flat structure
        source_base="ccpm"
    fi

    for dir in "${SYMLINK_DIRS[@]}"; do
        local target="$source_base/$dir"
        local link=".claude/$dir"

        # Check if source exists in submodule
        if [ ! -d "$SUBMODULE_PATH/${target#ccpm/}" ] && [ ! -d "$SUBMODULE_PATH/$dir" ]; then
            echo "  SKIP $dir (not in ccpm repo)"
            continue
        fi

        # Adjust target if flat structure
        if [ -d "$SUBMODULE_PATH/$dir" ] && [ ! -d "$SUBMODULE_PATH/ccpm/$dir" ]; then
            target="ccpm/$dir"
        fi

        # Remove existing (file, dir, or broken symlink)
        if [ -e "$link" ] || [ -L "$link" ]; then
            # Don't remove if it's already the correct symlink
            if [ -L "$link" ]; then
                current_target=$(readlink "$link")
                if [ "$current_target" = "$target" ]; then
                    echo "  OK   $link -> $target"
                    continue
                fi
            fi
            rm -rf "$link"
        fi

        # Create relative symlink
        ln -s "$target" "$link"
        echo "  NEW  $link -> $target"
    done
}

create_local_dirs() {
    echo ""
    echo "Creating local directories..."
    for dir in "${LOCAL_DIRS[@]}"; do
        if [ ! -d ".claude/$dir" ]; then
            mkdir -p ".claude/$dir"
            echo "  + .claude/$dir"
        fi
    done
}

make_scripts_executable() {
    # Make scripts executable (following symlinks)
    if [ -d ".claude/scripts" ]; then
        find -L ".claude/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    fi
}

update_gitignore() {
    # Add .claude/.backups to .gitignore
    if [ -f ".gitignore" ]; then
        grep -q "^\.claude/\.backups" .gitignore 2>/dev/null || echo ".claude/.backups" >> .gitignore
    else
        echo ".claude/.backups" > .gitignore
    fi

    # Add local dirs to gitignore (optional, depends on preference)
    grep -q "^\.claude/local" .gitignore 2>/dev/null || echo ".claude/local" >> .gitignore
}

configure_submodule() {
    echo ""
    echo "Configuring submodule..."

    # Set submodule to track branch
    git config -f .gitmodules submodule."$SUBMODULE_PATH".branch "$CCPM_BRANCH"

    # Optional: set update strategy
    git config -f .gitmodules submodule."$SUBMODULE_PATH".update rebase

    echo "  Branch tracking: $CCPM_BRANCH"
}

# --- Main ---

init_submodule
update_submodule
configure_submodule
create_symlinks
create_local_dirs
make_scripts_executable
update_gitignore

echo ""
echo "=========================="
echo "Done!"
echo ""
echo "Structure:"
echo "  .claude/ccpm/     -> git submodule (tracked)"
echo "  .claude/commands/ -> symlink to ccpm"
echo "  .claude/scripts/  -> symlink to ccpm"
echo "  .claude/prds/     -> local project data"
echo ""
echo "Commands:"
echo "  Update ccpm:      git submodule update --remote .claude/ccpm"
echo "  Commit to ccpm:   /pm:ccpm-commit \"message\""
echo "  Pin version:      cd .claude/ccpm && git checkout <tag>"
echo ""

exit 0

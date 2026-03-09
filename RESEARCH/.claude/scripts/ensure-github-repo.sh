#!/bin/bash
# ensure-github-repo.sh - Ensure GitHub repository exists for project
#
# Usage:
#   ./ensure-github-repo.sh [options] [repo-name]
#
# Options:
#   --private     Create as private repository (default)
#   --public      Create as public repository
#   --push        Push initial commit if remote is empty
#   --no-push     Don't push initial commit
#
# If repo-name is not provided, uses current directory name.
# Creates repo if it doesn't exist, sets up remote origin.

set -e

# Parse arguments
REPO_NAME=""
VISIBILITY=""  # empty = prompt, "private" or "public" = non-interactive
AUTO_PUSH=""   # empty = prompt, "yes" or "no" = non-interactive

while [[ $# -gt 0 ]]; do
  case "$1" in
    --private)
      VISIBILITY="private"
      shift
      ;;
    --public)
      VISIBILITY="public"
      shift
      ;;
    --push)
      AUTO_PUSH="yes"
      shift
      ;;
    --no-push)
      AUTO_PUSH="no"
      shift
      ;;
    --help|-h)
      cat << 'EOF'
Ensure GitHub Repository Exists

Usage:
  ./ensure-github-repo.sh [options] [repo-name]

Options:
  --private     Create as private repository (default for non-interactive)
  --public      Create as public repository
  --push        Push initial commit if remote is empty
  --no-push     Don't push initial commit

Arguments:
  repo-name     Name for the repository (default: current directory name)

Behavior:
  1. Checks if repo exists in your GitHub account
  2. Creates repo if it doesn't exist
  3. Sets up remote origin if not configured
  4. Initializes git if needed

Examples:
  ./ensure-github-repo.sh                        # Interactive
  ./ensure-github-repo.sh --private my-project   # Non-interactive, private
  ./ensure-github-repo.sh --public --push        # Non-interactive, public, auto-push

Requires: gh CLI authenticated (gh auth login)
EOF
      exit 0
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "Run: ./ensure-github-repo.sh --help"
      exit 1
      ;;
    *)
      REPO_NAME="$1"
      shift
      ;;
  esac
done

# Default repo name to current directory
REPO_NAME="${REPO_NAME:-$(basename "$(pwd)")}"

# Check if gh is available
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) not found"
  echo ""
  echo "Install: https://cli.github.com/"
  exit 1
fi

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "❌ GitHub CLI not authenticated"
  echo ""
  echo "Run: gh auth login"
  exit 1
fi

# Get current GitHub username
GH_USER=$(gh api user --jq '.login' 2>/dev/null)
if [[ -z "$GH_USER" ]]; then
  echo "❌ Could not determine GitHub username"
  exit 1
fi

# Function to find available repo name (appends _1, _2, etc. if name taken)
find_available_repo_name() {
  local base_name="$1"
  local candidate="$base_name"
  local suffix=1

  while gh repo view "$GH_USER/$candidate" &> /dev/null; do
    # Repo exists - check if it's already ours (same origin)
    local current_origin=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$current_origin" == *"$GH_USER/$candidate"* ]]; then
      # This repo is already ours, use it
      echo "$candidate"
      return 0
    fi

    # Try next suffix
    candidate="${base_name}_${suffix}"
    ((suffix++))

    # Safety limit
    if [[ $suffix -gt 100 ]]; then
      echo ""
      return 1
    fi
  done

  echo "$candidate"
  return 0
}

echo "=== Ensure GitHub Repository ==="
echo ""

# Check if we already have a remote origin configured that works
current_origin=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$current_origin" ]] && [[ "$current_origin" == *"github.com"* ]]; then
  # Extract repo name from origin
  origin_repo=$(echo "$current_origin" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
  if gh repo view "$origin_repo" &> /dev/null; then
    echo "✓ Repository exists: https://github.com/$origin_repo"
    echo "✓ Remote origin already configured"
    FULL_REPO="$origin_repo"
    REPO_NAME=$(basename "$FULL_REPO")

    echo ""
    echo "Repository ready: https://github.com/$FULL_REPO"
    exit 0
  fi
fi

# Find an available repo name
ORIGINAL_NAME="$REPO_NAME"
REPO_NAME=$(find_available_repo_name "$ORIGINAL_NAME")

if [[ -z "$REPO_NAME" ]]; then
  echo "❌ Could not find available repository name after 100 attempts"
  exit 1
fi

if [[ "$REPO_NAME" != "$ORIGINAL_NAME" ]]; then
  echo "Repository name '$ORIGINAL_NAME' is taken."
  echo "Using available name: $REPO_NAME"
  echo ""
fi

FULL_REPO="$GH_USER/$REPO_NAME"

echo "Repository: $FULL_REPO"
echo ""

# Check if repo already exists (it's ours from find_available_repo_name)
if gh repo view "$FULL_REPO" &> /dev/null; then
  echo "✓ Repository exists: https://github.com/$FULL_REPO"

  # Check if we have a remote origin set
  current_origin=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ -z "$current_origin" ]]; then
    echo ""
    echo "Setting up remote origin..."
    git remote add origin "https://github.com/$FULL_REPO.git"
    echo "✓ Remote origin added"
  elif [[ "$current_origin" != *"$FULL_REPO"* ]]; then
    echo ""
    echo "⚠️  Current origin: $current_origin"
    echo "   Expected: https://github.com/$FULL_REPO.git"
    echo ""
    # In non-interactive mode, don't change existing origin
    if [[ -z "$VISIBILITY" ]] && [[ -z "$AUTO_PUSH" ]]; then
      read -p "Update origin to $FULL_REPO? (y/n): " update_origin
      if [[ "$update_origin" == "y" ]]; then
        git remote set-url origin "https://github.com/$FULL_REPO.git"
        echo "✓ Remote origin updated"
      fi
    else
      echo "   Keeping existing origin (non-interactive mode)"
    fi
  else
    echo "✓ Remote origin already configured"
  fi
else
  echo "Repository does not exist. Creating..."
  echo ""

  # Initialize git if needed
  if [[ ! -d ".git" ]]; then
    echo "Initializing git repository..."
    git init
    echo ""
  fi

  # Determine visibility
  if [[ -n "$VISIBILITY" ]]; then
    # Non-interactive mode
    is_private="$VISIBILITY"
  else
    # Interactive mode - prompt user
    read -p "Create as private repository? (y/n): " response
    if [[ "$response" == "y" ]]; then
      is_private="private"
    else
      is_private="public"
    fi
  fi

  # Create the repository
  if [[ "$is_private" == "private" ]]; then
    echo "Creating private repository..."
    gh repo create "$REPO_NAME" --private --source=. --remote=origin
  else
    echo "Creating public repository..."
    gh repo create "$REPO_NAME" --public --source=. --remote=origin
  fi

  echo ""
  echo "✅ Repository created: https://github.com/$FULL_REPO"
fi

echo ""

# Check if we have any commits
if git rev-parse HEAD &> /dev/null; then
  # Check if we need to push
  if git remote get-url origin &> /dev/null; then
    # Check if remote has any commits
    if ! git ls-remote --heads origin main &> /dev/null && ! git ls-remote --heads origin master &> /dev/null; then
      echo "Remote is empty."

      # Determine whether to push
      if [[ "$AUTO_PUSH" == "yes" ]]; then
        do_push="y"
      elif [[ "$AUTO_PUSH" == "no" ]]; then
        do_push="n"
      else
        # Interactive mode
        read -p "Push initial commit? (y/n): " do_push
      fi

      if [[ "$do_push" == "y" ]]; then
        # Determine default branch name
        default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
        git push -u origin "$default_branch"
        echo "✓ Pushed to origin/$default_branch"
      fi
    else
      echo "✓ Remote has commits"
    fi
  fi
else
  echo "No commits yet. Create initial commit after adding files."
fi

echo ""
echo "Repository ready: https://github.com/$FULL_REPO"

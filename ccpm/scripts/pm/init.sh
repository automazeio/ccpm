#!/bin/bash

echo "Initializing..."
echo ""
echo ""

echo " ██████╗ ██████╗██████╗ ███╗   ███╗"
echo "██╔════╝██╔════╝██╔══██╗████╗ ████║"
echo "██║     ██║     ██████╔╝██╔████╔██║"
echo "╚██████╗╚██████╗██║     ██║ ╚═╝ ██║"
echo " ╚═════╝ ╚═════╝╚═╝     ╚═╝     ╚═╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Project Management  │"
echo "│ by https://x.com/aroussi        │"
echo "└─────────────────────────────────┘"
echo "https://github.com/automazeio/ccpm"
echo ""
echo ""

echo "🚀 Initializing Claude Code PM System"
echo "======================================"
echo ""

# Check for required tools
echo "🔍 Checking dependencies..."

# Check gh CLI
if command -v gh &> /dev/null; then
  echo "  ✅ GitHub CLI (gh) installed"
else
  echo "  ❌ GitHub CLI (gh) not found"
  echo ""
  echo "  Installing gh..."
  if command -v brew &> /dev/null; then
    brew install gh
  elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install gh
  else
    echo "  Please install GitHub CLI manually: https://cli.github.com/"
    exit 1
  fi
fi

# Check gh auth status
echo ""
echo "🔐 Checking GitHub authentication..."
if gh auth status &> /dev/null; then
  echo "  ✅ GitHub authenticated"
else
  echo "  ⚠️ GitHub not authenticated"
  echo "  Running: gh auth login"
  gh auth login
fi

# Check for gh-sub-issue extension
echo ""
echo "📦 Checking gh extensions..."
if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  echo "  ✅ gh-sub-issue extension installed"
else
  echo "  📥 Installing gh-sub-issue extension..."
  gh extension install yahsan2/gh-sub-issue
fi

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
mkdir -p ccpm/prds
mkdir -p ccpm/epics
mkdir -p ccpm/rules
mkdir -p ccpm/agents
mkdir -p ccpm/scripts/pm
echo "  ✅ Directories created"

# Copy scripts if in main repo
if [ -d "scripts/pm" ] && [ ! "$(pwd)" = *"/ccpm"* ]; then
  echo ""
  echo "📝 Copying PM scripts..."
  cp -r scripts/pm/* ccpm/scripts/pm/
  chmod +x ccpm/scripts/pm/*.sh
  echo "  ✅ Scripts copied and made executable"
fi

# Check for git
echo ""
echo "🔗 Checking Git configuration..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git repository detected"

  # Check remote
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ Remote configured: $remote_url"
    
    # Check if remote is the CCPM template repository
    if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
      echo ""
      echo "  ⚠️ WARNING: Your remote origin points to the CCPM template repository!"
      echo "  This means any issues you create will go to the template repo, not your project."
      echo ""
      echo "  To fix this:"
      echo "  1. Fork the repository or create your own on GitHub"
      echo "  2. Update your remote:"
      echo "     git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
      echo ""
    else
      # Create GitHub labels if this is a GitHub repository
      if gh repo view &> /dev/null; then
        echo ""
        echo "🏷️ Creating GitHub labels..."
        
        # Create base labels with improved error handling
        epic_created=false
        task_created=false
        
        if gh label create "epic" --color "0E8A16" --description "Epic issue containing multiple related tasks" --force 2>/dev/null; then
          epic_created=true
        elif gh label list 2>/dev/null | grep -q "^epic"; then
          epic_created=true  # Label already exists
        fi
        
        if gh label create "task" --color "1D76DB" --description "Individual task within an epic" --force 2>/dev/null; then
          task_created=true
        elif gh label list 2>/dev/null | grep -q "^task"; then
          task_created=true  # Label already exists
        fi
        
        # Report results
        if $epic_created && $task_created; then
          echo "  ✅ GitHub labels created (epic, task)"
        elif $epic_created || $task_created; then
          echo "  ⚠️ Some GitHub labels created (epic: $epic_created, task: $task_created)"
        else
          echo "  ❌ Could not create GitHub labels (check repository permissions)"
        fi
      else
        echo "  ℹ️ Not a GitHub repository - skipping label creation"
      fi
    fi
  else
    echo "  ⚠️ No remote configured"
    echo "  Add with: git remote add origin <url>"
  fi
else
  echo "  ⚠️ Not a git repository"
  echo "  Initialize with: git init"
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "CLAUDE.md" ]; then
  echo ""
  echo "📄 Creating CLAUDE.md..."
  cat > CLAUDE.md << 'EOF'
# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

Add your project-specific instructions here.

## Testing

Always run tests before committing:
- `npm test` or equivalent for your stack

## Code Style

Follow existing patterns in the codebase.
EOF
  echo "  ✅ CLAUDE.md created"
fi

# Summary
echo ""
echo "✅ Initialization Complete!"
echo "=========================="
echo ""
echo "📊 System Status:"
gh --version | head -1
echo "  Extensions: $(gh extension list | wc -l) installed"
echo "  Auth: $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
echo ""
echo "🎯 Next Steps:"
echo "  1. Create your first PRD: /pm:prd-new <feature-name>"
echo "  2. View help: /pm:help"
echo "  3. Check status: /pm:status"
echo ""
echo "📚 Documentation: README.md"

exit 0

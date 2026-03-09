# GitHub Operations Rule

Standard patterns for GitHub CLI operations across all commands.

## CRITICAL: Repository Protection

**Before ANY GitHub operation that creates/modifies issues or PRs:**

```bash
# Check if remote origin is the CCPM template repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
  echo "❌ ERROR: You're trying to sync with the CCPM template repository!"
  echo ""
  echo "This repository (automazeio/ccpm) is a template for others to use."
  echo "You should NOT create issues or PRs here."
  echo ""
  echo "To fix this:"
  echo "1. Fork this repository to your own GitHub account"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Or if this is a new project:"
  echo "1. Create a new repository on GitHub"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Current remote: $remote_url"
  exit 1
fi
```

This check MUST be performed in ALL commands that:
- Create issues (`gh issue create`)
- Edit issues (`gh issue edit`)
- Comment on issues (`gh issue comment`)
- Create PRs (`gh pr create`)
- Any other operation that modifies the GitHub repository

## Authentication

**Don't pre-check authentication.** Just run the command and handle failure:

```bash
gh {command} || echo "❌ GitHub CLI failed. Run: gh auth login"
```

## Common Operations

### Get Issue Details
```bash
gh issue view {number} --json state,title,labels,body
```

### Create Issue
```bash
# Always specify repo to avoid defaulting to wrong repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && REPO="user/repo"
gh issue create --repo "$REPO" --title "{title}" --body-file {file} --label "{labels}"
```

### Update Issue
```bash
# ALWAYS check remote origin first!
gh issue edit {number} --add-label "{label}" --add-assignee @me
```

### Add Comment
```bash
# ALWAYS check remote origin first!
gh issue comment {number} --body-file {file}
```

## Error Handling

If any gh command fails:
1. Show clear error: "❌ GitHub operation failed: {command}"
2. Suggest fix: "Run: gh auth login" or check issue number
3. Don't retry automatically

## Important Notes

- **ALWAYS** check remote origin before ANY write operation to GitHub
- Trust that gh CLI is installed and authenticated
- Use --json for structured output when parsing
- Keep operations atomic - one gh command per action
- Don't check rate limits preemptively

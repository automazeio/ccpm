# GitHub Operations Rule

Standard patterns for GitHub CLI operations across all commands.

## Repository Protection

Run this check before any GitHub operation that creates or modifies issues or PRs (the CCPM template repo must not receive issue/PR traffic from user projects):

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
  echo "ERROR: You're trying to sync with the CCPM template repository!"
  echo ""
  echo "This repository (automazeio/ccpm) is a template for others to use."
  echo "Do not create issues or PRs here."
  echo ""
  echo "To fix this:"
  echo "1. Fork this repository to your own GitHub account"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Or for a new project:"
  echo "1. Create a new repository on GitHub"
  echo "2. Update your remote origin:"
  echo "   git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
  echo ""
  echo "Current remote: $remote_url"
  exit 1
fi
```

Run this check in all commands that:
- Create issues (`gh issue create`)
- Edit issues (`gh issue edit`)
- Comment on issues (`gh issue comment`)
- Create PRs (`gh pr create`)
- Perform any other operation that modifies the GitHub repository

## Authentication

Run the command directly and handle failure — do not pre-check authentication:

```bash
gh {command} || echo "GitHub CLI failed. Run: gh auth login"
```

## Common Operations

### Get Issue Details
```bash
gh issue view {number} --json state,title,labels,body
```

### Create Issue
```bash
# Specify repo explicitly to avoid defaulting to the wrong repository
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && REPO="user/repo"
gh issue create --repo "$REPO" --title "{title}" --body-file {file} --label "{labels}"
```

### Update Issue
```bash
# Check remote origin first (see Repository Protection above)
gh issue edit {number} --add-label "{label}" --add-assignee @me
```

### Add Comment
```bash
# Check remote origin first (see Repository Protection above)
gh issue comment {number} --body-file {file}
```

## Error Handling

When a `gh` command fails:
1. Show a clear error: `GitHub operation failed: {command}`
2. Suggest fix: `Run: gh auth login` or check the issue number
3. Do not retry automatically

## Key Points

- Check remote origin before every write operation to GitHub
- Use `--json` for structured output when parsing
- Keep operations atomic — one `gh` command per action
- Do not check rate limits preemptively

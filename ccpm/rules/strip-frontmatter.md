# Strip Frontmatter

Standard approach for removing YAML frontmatter before sending content to GitHub.

## The Problem

YAML frontmatter contains internal metadata that should not appear in GitHub issues:
- `status`, `created`, `updated` fields
- Internal references and IDs
- Local file paths

## The Solution

Use `sed` to strip frontmatter from any markdown file:

```bash
# Strip frontmatter (everything between first two --- lines)
sed '1,/^---$/d; 1,/^---$/d' input.md > output.md
```

This removes the opening `---` line, all YAML content, and the closing `---` line.

## When to Strip Frontmatter

Strip frontmatter when:
- Creating GitHub issues from markdown files
- Posting file content as comments
- Displaying content to external users
- Syncing to any external system

## Examples

### Creating an issue from a file
```bash
# Without stripping — includes frontmatter (bad)
gh issue create --body-file task.md

# With stripping — clean content, correct repo (good)
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
[ -z "$REPO" ] && REPO="user/repo"
sed '1,/^---$/d; 1,/^---$/d' task.md > /tmp/clean.md
gh issue create --repo "$REPO" --body-file /tmp/clean.md
```

### Posting a comment
```bash
sed '1,/^---$/d; 1,/^---$/d' progress.md > /tmp/comment.md
gh issue comment 123 --body-file /tmp/comment.md
```

### In a loop
```bash
for file in *.md; do
  sed '1,/^---$/d; 1,/^---$/d' "$file" > "/tmp/$(basename $file)"
  # Use the clean version
done
```

## Alternative Approaches

```bash
# Using awk
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm==2{print}' input.md > output.md

# Using grep with line numbers
grep -n "^---$" input.md | head -2 | tail -1 | cut -d: -f1 | xargs -I {} tail -n +$(({}+1)) input.md
```

## Notes

- Test with a sample file when unsure
- Keep original files intact — always write cleaned content to a temp file
- Files without frontmatter are handled gracefully by the `sed` command

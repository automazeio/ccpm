# Strip Frontmatter

Standard approach for removing YAML frontmatter before sending content to GitHub.

## The Problem

YAML frontmatter contains internal metadata that should not appear in GitHub issues:
- status, created, updated fields
- Internal references and IDs
- Local file paths

## The Solution

### Safe Stripping Function (Recommended)

Use the provided utility function that handles empty files:

```bash
# Source utility functions
source "$HOME/.claude/scripts/pm/lib/utils.sh"

# Strip frontmatter safely with default content
strip_frontmatter_safe "input.md" "output.md" "Content pending."
```

This function:
1. Strips frontmatter using the standard sed pattern
2. Checks if the output file is empty
3. Provides default content if needed
4. Prevents empty GitHub issue bodies

### Basic sed Command

For simple cases where empty files are not a concern:

```bash
# Strip frontmatter (everything between first two --- lines)
sed '1,/^---$/d; 1,/^---$/d' input.md > output.md
```

**WARNING**: Files containing only frontmatter will result in empty output!

## When to Strip Frontmatter

Always strip frontmatter when:
- Creating GitHub issues from markdown files
- Posting file content as comments
- Displaying content to external users
- Syncing to any external system

## Examples

### Creating an issue from a file
```bash
# Bad - includes frontmatter
gh issue create --body-file task.md

# Good - strips frontmatter safely
source "$HOME/.claude/scripts/pm/lib/utils.sh"
strip_frontmatter_safe "task.md" "/tmp/clean.md" "Task details pending."
gh issue create --body-file /tmp/clean.md
```

### Posting a comment
```bash
# Strip frontmatter before posting
source "$HOME/.claude/scripts/pm/lib/utils.sh"
strip_frontmatter_safe "progress.md" "/tmp/comment.md" "Update pending."
gh issue comment 123 --body-file /tmp/comment.md
```

### In a loop
```bash
for file in *.md; do
  # Strip frontmatter from each file
  sed '1,/^---$/d; 1,/^---$/d' "$file" > "/tmp/$(basename $file)"
  # Use the clean version
done
```

## Alternative Approaches

If sed is not available or you need more control:

```bash
# Using awk
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm==2{print}' input.md > output.md

# Using grep with line numbers
grep -n "^---$" input.md | head -2 | tail -1 | cut -d: -f1 | xargs -I {} tail -n +$(({}+1)) input.md
```

## Important Notes

- Always test with a sample file first
- Keep original files intact
- Use temporary files for cleaned content
- Some files may not have frontmatter - the command handles this gracefully
# DateTime Rule

## Getting Current Date and Time

When any command requires the current date/time (for frontmatter, timestamps, or logs), you MUST obtain the REAL current date/time from the system rather than estimating or using placeholder values.

### How to Get Current DateTime

Use the `date` command to get the current ISO 8601 formatted datetime:

```bash
# Get current datetime in ISO 8601 format (works on Linux/Mac)
date -u +"%Y-%m-%dT%H:%M:%SZ"

# Alternative for systems that support it
date --iso-8601=seconds

# For Windows (if using PowerShell)
Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
```

### Required Format

All dates in frontmatter MUST use ISO 8601 format with UTC timezone:
- Format: `YYYY-MM-DDTHH:MM:SSZ`
- Example: `2024-01-15T14:30:45Z`

### Usage in Frontmatter

When creating or updating frontmatter in any file (PRD, Epic, Task, Progress), always use the real current datetime:

```yaml
---
name: feature-name
created: 2024-01-15T14:30:45Z  # Use actual output from date command
updated: 2024-01-15T14:30:45Z  # Use actual output from date command
---
```

### Implementation Instructions

1. **Before writing any file with frontmatter:**
   - Run: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
   - Store the output
   - Use this exact value in the frontmatter

2. **For commands that create files:**
   - PRD creation: Use real date for `created` field
   - Epic creation: Use real date for `created` field
   - Task creation: Use real date for both `created` and `updated` fields
   - Progress tracking: Use real date for `started` and `last_sync` fields

3. **For commands that update files:**
   - Always update the `updated` field with current real datetime
   - Preserve the original `created` field
   - For sync operations, update `last_sync` with real datetime

### Examples

**Creating a new PRD:**
```bash
# First, get current datetime
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Output: 2024-01-15T14:30:45Z

# Then use in frontmatter:
---
name: user-authentication
description: User authentication and authorization system
status: backlog
created: 2024-01-15T14:30:45Z  # Use the actual $CURRENT_DATE value
---
```

**Updating an existing task:**
```bash
# Get current datetime for update
UPDATE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update only the 'updated' field:
---
name: implement-login-api
status: in-progress
created: 2024-01-10T09:15:30Z  # Keep original
updated: 2024-01-15T14:30:45Z  # Use new $UPDATE_DATE value
---
```

### Important Notes

- **Never use placeholder dates** like `[Current ISO date/time]` or `YYYY-MM-DD`
- **Never estimate dates** - always get the actual system time
- **Always use UTC** (the `Z` suffix) for consistency across timezones
- **Preserve timezone consistency** - all dates in the system use UTC

### Cross-Platform Compatibility

If you need to ensure compatibility across different systems:

```bash
# Try primary method first
date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
# Fallback for systems without -u flag
date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
# Last resort: use Python if available
python3 -c "from datetime import datetime; print(datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null || \
python -c "from datetime import datetime; print(datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null
```

## Rule Priority

This rule has **HIGHEST PRIORITY** and must be followed by all commands that:
- Create new files with frontmatter
- Update existing files with frontmatter
- Track timestamps or progress
- Log any time-based information

Commands affected: prd-new, prd-parse, epic-decompose, epic-sync, issue-start, issue-sync, and any other command that writes timestamps.
# DateTime Rule

## Getting Current Date and Time

When any command requires the current date/time (for frontmatter, timestamps, or logs), obtain the real current date/time from the system rather than estimating or using placeholder values.

### How to Get Current DateTime

```bash
# Get current datetime in ISO 8601 format (Linux/Mac)
date -u +"%Y-%m-%dT%H:%M:%SZ"

# Alternative for systems that support it
date --iso-8601=seconds

# Windows PowerShell
Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
```

### Required Format

All dates in frontmatter use ISO 8601 format with UTC timezone:
- Format: `YYYY-MM-DDTHH:MM:SSZ`
- Example: `2024-01-15T14:30:45Z`

### Usage in Frontmatter

```yaml
---
name: feature-name
created: 2024-01-15T14:30:45Z  # actual output from date command
updated: 2024-01-15T14:30:45Z  # actual output from date command
---
```

### Implementation Instructions

**Before writing any file with frontmatter:**
1. Run: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
2. Store the output
3. Use this exact value in the frontmatter

**When creating files:**
- PRD creation: use real date for `created` field
- Epic creation: use real date for `created` field
- Task creation: use real date for both `created` and `updated` fields
- Progress tracking: use real date for `started` and `last_sync` fields

**When updating files:**
- Update the `updated` field with current real datetime
- Preserve the original `created` field
- For sync operations, update `last_sync` with real datetime

### Examples

**Creating a new PRD:**
```bash
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

---
name: user-authentication
description: User authentication and authorization system
status: backlog
created: 2024-01-15T14:30:45Z  # $CURRENT_DATE value
---
```

**Updating an existing task:**
```bash
UPDATE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

---
name: implement-login-api
status: in-progress
created: 2024-01-10T09:15:30Z  # preserve original
updated: 2024-01-15T14:30:45Z  # $UPDATE_DATE value
---
```

### Cross-Platform Compatibility

```bash
# Try primary method first, fall back through alternatives
date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
python3 -c "from datetime import datetime; print(datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null || \
python -c "from datetime import datetime; print(datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null
```

### Key Points

- Use placeholder dates like `[Current ISO date/time]` or `YYYY-MM-DD` only as documentation examples, never in actual files
- Get the actual system time rather than estimating
- Use UTC (the `Z` suffix) for consistency across timezones
- All dates in the system use UTC

## Scope

This rule applies to all commands that:
- Create new files with frontmatter
- Update existing files with frontmatter
- Track timestamps or progress
- Log any time-based information

Commands affected: `prd-new`, `prd-parse`, `epic-decompose`, `epic-sync`, `issue-start`, `issue-sync`, and any other command that writes timestamps.

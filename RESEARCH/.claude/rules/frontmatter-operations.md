# Frontmatter Operations Rule

Standard patterns for working with YAML frontmatter in markdown files.

## Reading Frontmatter

Extract frontmatter from any markdown file:
1. Look for content between `---` markers at start of file
2. Parse as YAML
3. If invalid or missing, use sensible defaults

## Updating Frontmatter

When updating existing files:
1. Preserve all existing fields
2. Only update specified fields
3. Always update `updated` field with current datetime (see `/rules/datetime.md`)

## Standard Fields

### All Files
```yaml
---
name: {identifier}
created: {ISO datetime}      # Never change after creation
updated: {ISO datetime}      # Update on any modification
---
```

### Status Values
- PRDs: `backlog`, `in-progress`, `complete`
- Epics: `backlog`, `in-progress`, `completed`  
- Tasks: `open`, `in-progress`, `closed`

### Progress Tracking
```yaml
progress: {0-100}%           # For epics
completion: {0-100}%         # For progress files
```

## Creating New Files

Always include frontmatter when creating markdown files:
```yaml
---
name: {from_arguments_or_context}
status: {initial_status}
created: {current_datetime}
updated: {current_datetime}
---
```

## Important Notes

- Never modify `created` field after initial creation
- Always use real datetime from system (see `/rules/datetime.md`)
- Validate frontmatter exists before trying to parse
- Use consistent field names across all files
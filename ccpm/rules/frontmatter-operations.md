# Frontmatter Operations Rule

Standard patterns for working with YAML frontmatter in markdown files.

## Reading Frontmatter

1. Look for content between `---` markers at the start of the file
2. Parse as YAML
3. If invalid or missing, use sensible defaults

## Updating Frontmatter

1. Preserve all existing fields
2. Update only specified fields
3. Update the `updated` field with current datetime (see `/rules/datetime.md`)

## Standard Fields

### All Files
```yaml
---
name: {identifier}
created: {ISO datetime}      # Preserve after creation — never change
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

Include frontmatter in all new markdown files:
```yaml
---
name: {from_arguments_or_context}
status: {initial_status}
created: {current_datetime}
updated: {current_datetime}
---
```

## Key Points

- Preserve the `created` field after initial creation
- Use real datetime from system (see `/rules/datetime.md`)
- Validate frontmatter exists before parsing
- Use consistent field names across all files

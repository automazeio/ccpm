---
allowed-tools: Bash, Read, Write, LS
---

# Create Initial Context

This command creates the initial project context documentation in `.claude/context/` by analyzing the current project state and establishing comprehensive baseline documentation.

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### 1. Context Directory Check
- Run: `ls -la .claude/context/ 2>/dev/null`
- If directory exists and has files:
  - Count existing files: `ls -1 .claude/context/*.md 2>/dev/null | wc -l`
  - Ask user: "⚠️ Found {count} existing context files. Overwrite all context? (yes/no)"
  - Only proceed with explicit 'yes' confirmation
  - If user says no, suggest: "Use /context:update to refresh existing context"

### 2. Project Type Detection
- Check for project indicators:
  - Node.js: `test -f package.json && echo "Node.js project detected"`
  - Python: `test -f requirements.txt || test -f pyproject.toml && echo "Python project detected"`
  - Rust: `test -f Cargo.toml && echo "Rust project detected"`
  - Go: `test -f go.mod && echo "Go project detected"`
- Run: `git status 2>/dev/null` to confirm this is a git repository
- If not a git repo, ask: "⚠️ Not a git repository. Continue anyway? (yes/no)"

### 3. Directory Creation
- If `.claude/` doesn't exist, create it: `mkdir -p .claude/context/`
- Verify write permissions: `touch .claude/context/.test && rm .claude/context/.test`
- If permission denied, tell user: "❌ Cannot create context directory. Check permissions."

### 4. Get Current DateTime
- Run: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- Store this value for use in all context file frontmatter

## Instructions

### 1. Pre-Analysis Validation
- Confirm project root directory is correct (presence of .git, package.json, etc.)
- Check for existing documentation that can inform context (README.md, docs/)
- If README.md doesn't exist, ask user for project description

### 2. Systematic Project Analysis
Gather information in this order:

**Project Detection:**
- Run: `find . -maxdepth 2 -name 'package.json' -o -name 'requirements.txt' -o -name 'Cargo.toml' -o -name 'go.mod' 2>/dev/null`
- Run: `git remote -v 2>/dev/null` to get repository information
- Run: `git branch --show-current 2>/dev/null` to get current branch

**Codebase Analysis:**
- Run: `find . -type f -name '*.js' -o -name '*.py' -o -name '*.rs' -o -name '*.go' 2>/dev/null | head -20`
- Run: `ls -la` to see root directory structure
- Read README.md if it exists

### 3. Context File Creation with Frontmatter

Each context file MUST include frontmatter with real datetime:

```yaml
---
created: [Use REAL datetime from date command]
last_updated: [Use REAL datetime from date command]
version: 1.0
author: Claude Code PM System
---
```

Generate the following initial context files:
  - `progress.md` - Document current project status, completed work, and immediate next steps
    - Include: Current branch, recent commits, outstanding changes
  - `project-structure.md` - Map out the directory structure and file organization
    - Include: Key directories, file naming patterns, module organization
  - `tech-context.md` - Catalog current dependencies, technologies, and development tools
    - Include: Language version, framework versions, dev dependencies
  - `system-patterns.md` - Identify existing architectural patterns and design decisions
    - Include: Design patterns observed, architectural style, data flow
  - `product-context.md` - Define product requirements, target users, and core functionality
    - Include: User personas, core features, use cases
  - `project-brief.md` - Establish project scope, goals, and key objectives
    - Include: What it does, why it exists, success criteria
  - `project-overview.md` - Provide a high-level summary of features and capabilities
    - Include: Feature list, current state, integration points
  - `project-vision.md` - Articulate long-term vision and strategic direction
    - Include: Future goals, potential expansions, strategic priorities
  - `project-style-guide.md` - Document coding standards, conventions, and style preferences
    - Include: Naming conventions, file structure patterns, comment style
### 4. Quality Validation

After creating each file:
- Verify file was created successfully
- Check file is not empty (minimum 10 lines of content)
- Ensure frontmatter is present and valid
- Validate markdown formatting is correct

### 5. Error Handling

**Common Issues:**
- **No write permissions:** "❌ Cannot write to .claude/context/. Check permissions."
- **Disk space:** "❌ Insufficient disk space for context files."
- **File creation failed:** "❌ Failed to create {filename}. Error: {error}"

If any file fails to create:
- Report which files were successfully created
- Provide option to continue with partial context
- Never leave corrupted or incomplete files

### 6. Post-Creation Summary

Provide comprehensive summary:
```
📋 Context Creation Complete

📁 Created context in: .claude/context/
✅ Files created: {count}/9

📊 Context Summary:
  - Project Type: {detected_type}
  - Language: {primary_language}
  - Git Status: {clean/changes}
  - Dependencies: {count} packages

📝 File Details:
  ✅ progress.md ({lines} lines) - Current status and recent work
  ✅ project-structure.md ({lines} lines) - Directory organization
  [... list all files with line counts and brief description ...]

⏰ Created: {timestamp}
🔄 Next: Use /context:prime to load context in new sessions
💡 Tip: Run /context:update regularly to keep context current
```

## Context Gathering Commands

Use these commands to gather project information:
- Target directory: `.claude/context/` (create if needed)
- Current git status: `git status --short`
- Recent commits: `git log --oneline -10`
- Project README: Read `README.md` if exists
- Package files: Check for `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, etc.
- Documentation scan: `find . -type f -name '*.md' -path '*/docs/*' 2>/dev/null | head -10`
- Test detection: `find . -type d \( -name 'test' -o -name 'tests' -o -name '__tests__' -o -name 'spec' \) 2>/dev/null | head -5`

## Important Notes

- **Always use real datetime** from system clock, never placeholders
- **Ask for confirmation** before overwriting existing context
- **Validate each file** is created successfully
- **Provide detailed summary** of what was created
- **Handle errors gracefully** with specific guidance

$ARGUMENTS

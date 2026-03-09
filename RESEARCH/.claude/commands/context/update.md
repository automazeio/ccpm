---
allowed-tools: Bash, Read, Write, LS
---

# Update Context

This command updates the project context documentation in `.claude/context/` to reflect the current state of the project. Run this at the end of each development session to keep context accurate.

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### 1. Context Validation
- Run: `ls -la .claude/context/ 2>/dev/null`
- If directory doesn't exist or is empty:
  - Tell user: "❌ No context to update. Please run /context:create first."
  - Exit gracefully
- Count existing files: `ls -1 .claude/context/*.md 2>/dev/null | wc -l`
- Report: "📁 Found {count} context files to check for updates"

### 2. Change Detection

Gather information about what has changed:

**Git Changes:**
- Run: `git status --short` to see uncommitted changes
- Run: `git log --oneline -10` to see recent commits
- Run: `git diff --stat HEAD~5..HEAD 2>/dev/null` to see files changed recently

**File Modifications:**
- Check context file ages: `find .claude/context -name "*.md" -type f -exec ls -lt {} + | head -5`
- Note which context files are oldest and may need updates

**Dependency Changes:**
- Node.js: `git diff HEAD~5..HEAD package.json 2>/dev/null`
- Python: `git diff HEAD~5..HEAD requirements.txt pyproject.toml 2>/dev/null`
- Java: `git diff HEAD~5..HEAD pom.xml build.gradle build.gradle.kts 2>/dev/null`
- C#/.NET: `git diff HEAD~5..HEAD *.sln *.csproj 2>/dev/null`
- Ruby: `git diff HEAD~5..HEAD Gemfile Gemfile.lock 2>/dev/null`
- Rust: `git diff HEAD~5..HEAD Cargo.toml Cargo.lock 2>/dev/null`
- Go: `git diff HEAD~5..HEAD go.mod go.sum 2>/dev/null`
- PHP: `git diff HEAD~5..HEAD composer.json composer.lock 2>/dev/null`
- Dart/Flutter: `git diff HEAD~5..HEAD pubspec.yaml pubspec.lock 2>/dev/null`
- Swift: `git diff HEAD~5..HEAD Package.swift Package.resolved 2>/dev/null`
- C/C++: `git diff HEAD~5..HEAD CMakeLists.txt 2>/dev/null`
- Check if new dependencies were added or versions changed across any build system

### 3. Get Current DateTime
- Run: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- Store for updating `last_updated` field in modified files

## Instructions

### 1. Systematic Change Analysis

For each context file, determine if updates are needed:

**Check each file systematically:**
#### `progress.md` - **Always Update**
  - Check: Recent commits, current branch, uncommitted changes
  - Update: Latest completed work, current blockers, next steps
  - Run: `git log --oneline -5` to get recent commit messages
  - Include completion percentages if applicable

#### `project-structure.md` - **Update if Changed**
  - Check: `git diff --name-status HEAD~10..HEAD | grep -E '^A'` for new files
  - Update: New directories, moved files, structural reorganization
  - Only update if significant structural changes occurred

#### `tech-context.md` - **Update if Dependencies Changed**
  - Check: Package files for new dependencies or version changes
  - Update: New libraries, upgraded versions, new dev tools
  - Include security updates or breaking changes

#### `system-patterns.md` - **Update if Architecture Changed**
  - Check: New design patterns, architectural decisions
  - Update: New patterns adopted, refactoring done
  - Only update for significant architectural changes

#### `product-context.md` - **Update if Requirements Changed**
  - Check: New features implemented, user feedback incorporated
  - Update: New user stories, changed requirements
  - Include any pivot in product direction

#### `project-brief.md` - **Rarely Update**
  - Check: Only if fundamental project goals changed
  - Update: Major scope changes, new objectives
  - Usually remains stable

#### `project-overview.md` - **Update for Major Milestones**
  - Check: Major features completed, significant progress
  - Update: Feature status, capability changes
  - Update when reaching project milestones

#### `project-vision.md` - **Rarely Update**
  - Check: Strategic direction changes
  - Update: Only for major vision shifts
  - Usually remains stable

#### `project-style-guide.md` - **Update if Conventions Changed**
  - Check: New linting rules, style decisions
  - Update: Convention changes, new patterns adopted
  - Include examples of new patterns
### 2. Smart Update Strategy

**For each file that needs updating:**

1. **Read existing file** to understand current content
2. **Identify specific sections** that need updates
3. **Preserve frontmatter** but update `last_updated` field:
   ```yaml
   ---
   created: [preserve original]
   last_updated: [Use REAL datetime from date command]
   version: [increment if major update, e.g., 1.0 → 1.1]
   author: Claude Code PM System
   ---
   ```
4. **Make targeted updates** - don't rewrite entire file
5. **Add update notes** at the bottom if significant:
   ```markdown
   ## Update History
   - {date}: {summary of what changed}
   ```

### 3. Update Validation

After updating each file:
- Verify file still has valid frontmatter
- Check file size is reasonable (not corrupted)
- Ensure markdown formatting is preserved
- Confirm updates accurately reflect changes

### 4. Skip Optimization

**Skip files that don't need updates:**
- If no relevant changes detected, skip the file
- Report skipped files in summary
- Don't update timestamp if content unchanged
- This preserves accurate "last modified" information

### 5. Error Handling

**Common Issues:**
- **File locked:** "❌ Cannot update {file} - may be open in editor"
- **Permission denied:** "❌ Cannot write to {file} - check permissions"
- **Corrupted file:** "⚠️ {file} appears corrupted - skipping update"
- **Disk space:** "❌ Insufficient disk space for updates"

If update fails:
- Report which files were successfully updated
- Note which files failed and why
- Preserve original files (don't leave corrupted state)

### 6. Update Summary

Provide detailed summary of updates:

```
🔄 Context Update Complete

📊 Update Statistics:
  - Files Scanned: {total_count}
  - Files Updated: {updated_count}
  - Files Skipped: {skipped_count} (no changes needed)
  - Errors: {error_count}

📝 Updated Files:
  ✅ progress.md - Updated recent commits, current status
  ✅ tech-context.md - Added 3 new dependencies
  ✅ project-structure.md - Noted new /utils directory

⏭️ Skipped Files (no changes):
  - project-brief.md (last updated: 5 days ago)
  - project-vision.md (last updated: 2 weeks ago)
  - system-patterns.md (last updated: 3 days ago)

⚠️ Issues:
  {any warnings or errors}

⏰ Last Update: {timestamp}
🔄 Next: Run this command regularly to keep context current
💡 Tip: Major changes? Consider running /context:create for full refresh
```

### 7. Incremental Update Tracking

**Track what was updated:**
- Note which sections of each file were modified
- Keep changes focused and surgical
- Don't regenerate unchanged content
- Preserve formatting and structure

### 8. Performance Optimization

For large projects:
- Process files in parallel when possible
- Show progress: "Updating context files... {current}/{total}"
- Skip very large files with warning
- Use git diff to quickly identify changed areas

## Context Gathering Commands

Use these commands to detect changes:
- Context directory: `.claude/context/`
- Current git status: `git status --short`
- Recent commits: `git log --oneline -10`
- Changed files: `git diff --name-only HEAD~5..HEAD 2>/dev/null`
- Branch info: `git branch --show-current`
- Uncommitted changes: `git diff --stat`
- New untracked files: `git ls-files --others --exclude-standard | head -10`
- Dependency changes: Check package.json, requirements.txt, pyproject.toml, composer.json, Gemfile, Cargo.toml, go.mod, pom.xml, build.gradle, build.gradle.kts, *.sln, *.csproj, Package.swift, pubspec.yaml, CMakeLists.txt, etc.

## Important Notes

- **Only update files with actual changes** - preserve accurate timestamps
- **Always use real datetime** from system clock for `last_updated`
- **Make surgical updates** - don't regenerate entire files
- **Validate each update** - ensure files remain valid
- **Provide detailed summary** - show what changed and what didn't
- **Handle errors gracefully** - don't corrupt existing context

$ARGUMENTS

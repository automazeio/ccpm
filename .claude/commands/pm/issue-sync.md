---
allowed-tools: Bash, Read, Write, LS
---

# Issue Sync

Push local updates as GitHub issue comments for transparent audit trail.

## Usage
```
/pm:issue-sync <issue_number>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

0. **Repository Protection Check:**
   Follow `/rules/github-operations.md` - check remote origin:
   ```bash
   remote_url=$(git remote get-url origin 2>/dev/null || echo "")
   if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
     echo "❌ ERROR: Cannot sync to CCPM template repository!"
     echo "Update your remote: git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
     exit 1
   fi
   ```

1. **GitHub Authentication:**
   - Run: `gh auth status`
   - If not authenticated, tell user: "❌ GitHub CLI not authenticated. Run: gh auth login"

2. **Issue Validation:**
   - Run: `gh issue view $ARGUMENTS --json state`
   - If issue doesn't exist, tell user: "❌ Issue #$ARGUMENTS not found"
   - If issue is closed and completion < 100%, warn: "⚠️ Issue is closed but work incomplete"

3. **Local Updates Check:**
   - Check if `.claude/epics/*/updates/$ARGUMENTS/` directory exists
   - If not found, tell user: "❌ No local updates found for issue #$ARGUMENTS. Run: /pm:issue-start $ARGUMENTS"
   - Check if progress.md exists
   - If not, tell user: "❌ No progress tracking found. Initialize with: /pm:issue-start $ARGUMENTS"

4. **Check Last Sync:**
   - Read `last_sync` from progress.md frontmatter
   - If synced recently (< 5 minutes), ask: "⚠️ Recently synced. Force sync anyway? (yes/no)"
   - Calculate what's new since last sync

5. **Verify Changes:**
   - Check if there are actual updates to sync
   - If no changes, tell user: "ℹ️ No new updates to sync since {last_sync}"
   - Exit gracefully if nothing to sync

## Instructions

You are synchronizing local development progress to GitHub as issue comments for: **Issue #$ARGUMENTS**

### 1. Gather Local Updates
Collect all local updates for the issue:
- Read from `.claude/epics/{epic_name}/updates/$ARGUMENTS/`
- Check for new content in:
  - `progress.md` - Development progress
  - `notes.md` - Technical notes and decisions
  - `commits.md` - Recent commits and changes
  - Any other update files

### 2. Update Progress Tracking Frontmatter
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update the progress.md file frontmatter:
```yaml
---
issue: $ARGUMENTS
started: [preserve existing date]
last_sync: [Use REAL datetime from command above]
completion: [calculated percentage 0-100%]
---
```

### 3. Determine What's New
Compare against previous sync to identify new content:
- Look for sync timestamp markers
- Identify new sections or updates
- Gather only incremental changes since last sync

### 4. Format Update Comment
Create comprehensive update comment:

```markdown
## 🔄 Progress Update - {current_date}

### ✅ Completed Work
{list_completed_items}

### 🔄 In Progress
{current_work_items}

### 📝 Technical Notes
{key_technical_decisions}

### 📊 Acceptance Criteria Status
- ✅ {completed_criterion}
- 🔄 {in_progress_criterion}
- ⏸️ {blocked_criterion}
- □ {pending_criterion}

### 🚀 Next Steps
{planned_next_actions}

### ⚠️ Blockers
{any_current_blockers}

### 💻 Recent Commits
{commit_summaries}

---
*Progress: {completion}% | Synced from local updates at {timestamp}*
```

### 5. Post to GitHub
Use GitHub CLI to add comment:
```bash
gh issue comment #$ARGUMENTS --body-file {temp_comment_file}
```

### 6. Update Local Task File
Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Update the task file frontmatter with sync information:
```yaml
---
name: [Task Title]
status: open
created: [preserve existing date]
updated: [Use REAL datetime from command above]
github: https://github.com/{org}/{repo}/issues/$ARGUMENTS
---
```

### 7. Handle Completion
If task is complete, update all relevant frontmatter:

**Task file frontmatter**:
```yaml
---
name: [Task Title]
status: closed
created: [existing date]
updated: [current date/time]
github: https://github.com/{org}/{repo}/issues/$ARGUMENTS
---
```

**Progress file frontmatter**:
```yaml
---
issue: $ARGUMENTS
started: [existing date]
last_sync: [current date/time]
completion: 100%
---
```

**Epic progress update**: Recalculate epic progress based on completed tasks and update epic frontmatter:
```yaml
---
name: [Epic Name]
status: in-progress
created: [existing date]
progress: [calculated percentage based on completed tasks]%
prd: [existing path]
github: [existing URL]
---
```

### 8. Completion Comment
If task is complete:
```markdown
## ✅ Task Completed - {current_date}

### 🎯 All Acceptance Criteria Met
- ✅ {criterion_1}
- ✅ {criterion_2}
- ✅ {criterion_3}

### 📦 Deliverables
- {deliverable_1}
- {deliverable_2}

### 🧪 Testing
- Unit tests: ✅ Passing
- Integration tests: ✅ Passing
- Manual testing: ✅ Complete

### 📚 Documentation
- Code documentation: ✅ Updated
- README updates: ✅ Complete

This task is ready for review and can be closed.

---
*Task completed: 100% | Synced at {timestamp}*
```

### 9. Output Summary
```
☁️ Synced updates to GitHub Issue #$ARGUMENTS

📝 Update summary:
   Progress items: {progress_count}
   Technical notes: {notes_count}
   Commits referenced: {commit_count}

📊 Current status:
   Task completion: {task_completion}%
   Epic progress: {epic_progress}%
   Completed criteria: {completed}/{total}

🔗 View update: gh issue view #$ARGUMENTS --comments
```

### 10. Frontmatter Maintenance
- Always update task file frontmatter with current timestamp
- Track completion percentages in progress files
- Update epic progress when tasks complete
- Maintain sync timestamps for audit trail

### 11. Incremental Sync Detection

**Prevent Duplicate Comments:**
1. Add sync markers to local files after each sync:
   ```markdown
   <!-- SYNCED: 2024-01-15T10:30:00Z -->
   ```
2. Only sync content added after the last marker
3. If no new content, skip sync with message: "No updates since last sync"

### 12. Comment Size Management

**Handle GitHub's Comment Limits:**
- Max comment size: 65,536 characters
- If update exceeds limit:
  1. Split into multiple comments
  2. Or summarize with link to full details
  3. Warn user: "⚠️ Update truncated due to size. Full details in local files."

### 13. Error Handling

**Common Issues and Recovery:**

1. **Network Error:**
   - Message: "❌ Failed to post comment: network error"
   - Solution: "Check internet connection and retry"
   - Keep local updates intact for retry

2. **Rate Limit:**
   - Message: "❌ GitHub rate limit exceeded"
   - Solution: "Wait {minutes} minutes or use different token"
   - Save comment locally for later sync

3. **Permission Denied:**
   - Message: "❌ Cannot comment on issue (permission denied)"
   - Solution: "Check repository access permissions"

4. **Issue Locked:**
   - Message: "⚠️ Issue is locked for comments"
   - Solution: "Contact repository admin to unlock"

### 14. Epic Progress Calculation

When updating epic progress:
1. Count total tasks in epic directory
2. Count tasks with `status: closed` in frontmatter
3. Calculate: `progress = (closed_tasks / total_tasks) * 100`
4. Round to nearest integer
5. Update epic frontmatter only if percentage changed

### 15. Post-Sync Validation

After successful sync:
- [ ] Verify comment posted on GitHub
- [ ] Confirm frontmatter updated with sync timestamp
- [ ] Check epic progress updated if task completed
- [ ] Validate no data corruption in local files

This creates a transparent audit trail of development progress that stakeholders can follow in real-time for Issue #$ARGUMENTS, while maintaining accurate frontmatter across all project files.
